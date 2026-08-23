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

TRIME_VERSION="$(git describe --tags --long --always --exclude=nightly)"
echo "Using Trime version: $TRIME_VERSION"

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

# Build a single universal APK instead of ABI-specific APKs.
python3 - <<'PY'
from pathlib import Path

path = Path("build-logic/convention/src/main/kotlin/NativeBaseConventionPlugin.kt")
text = path.read_text(encoding="utf-8")
old = "isUniversalApk = false"
if old not in text:
    raise SystemExit(f"{path}: failed to find {old!r}")
text = text.replace(old, "isUniversalApk = true")
path.write_text(text, encoding="utf-8")
PY

SHARED_ASSETS="app/src/main/assets/shared"
mkdir -p "$SHARED_ASSETS"

cp -R "$REPO_ROOT/$SCHEMA_DIR"/. "$SHARED_ASSETS"/

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
