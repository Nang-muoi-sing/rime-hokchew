#!/usr/bin/env bash
set -euo pipefail

SCHEMA_DIR="${SCHEMA_DIR:-rime}"
OUTPUT_DIR="${OUTPUT_DIR:-output}"

PACKAGE_NAME="rime-hokchew"
TRIME_REPO="${TRIME_REPO:-https://github.com/osfans/trime.git}"
TRIME_REF="${TRIME_REF:-v3.3.11}"
TRIME_APP_ID="${TRIME_APP_ID:-com.seedict.trime}"
TRIME_WORKDIR="${TRIME_WORKDIR:-$OUTPUT_DIR/trime-work}"
REPO_ROOT="$PWD"

mkdir -p "$OUTPUT_DIR"

if [ ! -d "$SCHEMA_DIR" ]; then
  echo "Schema directory not found: $SCHEMA_DIR" >&2
  exit 1
fi

# 注入安装包默认启用方案配置
bash .ci/prepare-schema.sh

rm -rf "$TRIME_WORKDIR"
git clone "$TRIME_REPO" "$TRIME_WORKDIR"

pushd "$TRIME_WORKDIR" >/dev/null
git checkout "$TRIME_REF"
git submodule update --init --recursive --filter=blob:none
git config --global --add safe.directory "$PWD"

TRIME_VERSION="$(git describe --tags --long --always --exclude=nightly)"
TRIME_COMMIT="$(git rev-parse HEAD)"
TRIME_BUILDER="${GITHUB_ACTOR:-Seedict CI}"
echo "Using Trime version: $TRIME_VERSION"
echo "Using Trime commit: $TRIME_COMMIT"

python3 - <<'PY'
import os
from pathlib import Path

path = Path("app/build.gradle.kts")
text = path.read_text(encoding="utf-8")
app_id = os.environ["TRIME_APP_ID"]
old = 'applicationId = "com.osfans.trime"'
if old not in text:
    raise SystemExit(f"{path}: failed to find {old!r}")
text = text.replace(old, f'applicationId = "{app_id}"')
path.write_text(text, encoding="utf-8")
PY

echo "Patched Trime Gradle config:"
sed -n '25,40p' app/build.gradle.kts

SHARED_ASSETS="app/src/main/assets/shared"
mkdir -p "$SHARED_ASSETS"

cp -R "$REPO_ROOT/$SCHEMA_DIR"/. "$SHARED_ASSETS"/
echo "Injected Rime schemas into $SHARED_ASSETS:"
find "$SHARED_ASSETS" -maxdepth 1 -type f \( -name "hokchew*.yaml" -o -name "default.custom.yaml" \) -print | sort

find "$REPO_ROOT/theme" -maxdepth 1 -type f -name "*.trime.yaml" -exec cp {} "$SHARED_ASSETS"/ \;
if [ -d "$REPO_ROOT/theme/fonts" ]; then
  mkdir -p "$SHARED_ASSETS/fonts"
  find "$REPO_ROOT/theme/fonts" -maxdepth 1 -type f \
    \( -name "*.ttf" -o -name "*.otf" -o -name "*.ttc" \) \
    -exec cp {} "$SHARED_ASSETS/fonts"/ \;
fi
echo "Injected Trime themes into $SHARED_ASSETS:"
find "$SHARED_ASSETS" -maxdepth 2 \( \
  -type f -name "*.trime.yaml" \
  -o -type f -path "$SHARED_ASSETS/fonts/*" \
\) -print | sort

if [ -n "${ANDROID_KEYSTORE_BASE64:-}" ]; then
  if [ -z "${ANDROID_KEYSTORE_PASSWORD:-}" ] || [ -z "${ANDROID_KEY_PASSWORD:-}" ] || [ -z "${ANDROID_KEY_ALIAS:-}" ]; then
    echo "ANDROID_KEYSTORE_PASSWORD, ANDROID_KEY_PASSWORD, and ANDROID_KEY_ALIAS are required when ANDROID_KEYSTORE_BASE64 is set" >&2
    exit 1
  fi

  printf '%s' "$ANDROID_KEYSTORE_BASE64" | base64 --decode > seedict-trime.jks
  STORE_PASSWORD="$ANDROID_KEYSTORE_PASSWORD"
  KEY_PASSWORD="$ANDROID_KEY_PASSWORD"
  KEY_ALIAS="$ANDROID_KEY_ALIAS"
  STORE_FILE="$PWD/seedict-trime.jks"
else
  STORE_PASSWORD="$(openssl rand -base64 24)"
  KEY_PASSWORD="$(openssl rand -base64 24)"
  KEY_ALIAS="seedict-trime"
  STORE_FILE="$PWD/seedict-trime.jks"

  keytool -genkeypair \
    -alias "$KEY_ALIAS" \
    -keyalg RSA \
    -keysize 4096 \
    -validity 10000 \
    -keystore "$STORE_FILE" \
    -storepass "$STORE_PASSWORD" \
    -keypass "$KEY_PASSWORD" \
    -dname "CN=Seedict Trime, OU=Rime Hokchew, O=Seedict, L=Fuzhou, S=Fujian, C=CN"
fi

cat > keystore.properties <<EOF
storePassword=$STORE_PASSWORD
keyPassword=$KEY_PASSWORD
keyAlias=$KEY_ALIAS
storeFile=$STORE_FILE
EOF

echo "Building Trime APK with upstream Makefile:"
printf '  BUILD_GIT_REPO=%s\n' "$TRIME_REPO"
printf '  BUILD_VERSION_NAME=%s\n' "$TRIME_VERSION"
printf '  BUILD_COMMIT_HASH=%s\n' "$TRIME_COMMIT"
printf '  CI_NAME=%s\n' "$TRIME_BUILDER"
printf '  BUILD_ABI=%s\n' "${BUILD_ABI:-}"

BUILD_GIT_REPO="$TRIME_REPO" \
BUILD_VERSION_NAME="$TRIME_VERSION" \
BUILD_COMMIT_HASH="$TRIME_COMMIT" \
CI_NAME="$TRIME_BUILDER" \
BUILD_ABI="${BUILD_ABI:-arm64-v8a}" \
make release

popd >/dev/null

APK_OUTPUT_DIR="$TRIME_WORKDIR/app/build/outputs/apk/release"
if [ ! -d "$APK_OUTPUT_DIR" ]; then
  echo "APK output directory not found: $APK_OUTPUT_DIR" >&2
  exit 1
fi

mapfile -t APKS < <(find "$APK_OUTPUT_DIR" -maxdepth 1 -type f -name "*.apk" | sort)
if [ "${#APKS[@]}" -eq 0 ]; then
  echo "No APK produced in $APK_OUTPUT_DIR" >&2
  exit 1
fi

for apk in "${APKS[@]}"; do
  apk_base="$(basename "$apk")"
  final_name="${PACKAGE_NAME}-trime-${TRIME_VERSION}-${apk_base}"
  cp "$apk" "$OUTPUT_DIR/$final_name"
  echo "Built: $OUTPUT_DIR/$final_name"
done
