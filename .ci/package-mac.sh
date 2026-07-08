#!/usr/bin/env bash
set -euo pipefail

SCHEMA_DIR="${SCHEMA_DIR:-rime}"
OUTPUT_DIR="${OUTPUT_DIR:-output}"

PACKAGE_NAME="rime-hokchew"

mkdir -p "$OUTPUT_DIR"

# 注入安装包默认启用方案配置
bash .ci/prepare-schema.sh

SQUIRREL_TAG="$(gh release view --repo rime/squirrel --json tagName --jq .tagName)"
SQUIRREL_VERSION="${SQUIRREL_TAG#v}"

PKG_NAME="Squirrel-${SQUIRREL_VERSION}.pkg"
PKG_URL="https://github.com/rime/squirrel/releases/download/${SQUIRREL_TAG}/${PKG_NAME}"

echo "Using Squirrel version: $SQUIRREL_TAG"
echo "Downloading: $PKG_URL"

curl -L "$PKG_URL" -o "$OUTPUT_DIR/$PKG_NAME"

WORKDIR="$OUTPUT_DIR/squirrel-work"
rm -rf "$WORKDIR"
mkdir -p "$WORKDIR"

pkgutil --expand "$OUTPUT_DIR/$PKG_NAME" "$WORKDIR/package"

pushd "$WORKDIR/package" >/dev/null

PAYLOAD_ROOT="payload-root"
rm -rf "$PAYLOAD_ROOT"
mkdir -p "$PAYLOAD_ROOT"

(
  cd "$PAYLOAD_ROOT"
  gunzip -dc ../Payload | cpio -i
)

SUPPORT_DIR="$PAYLOAD_ROOT/Squirrel.app/Contents/SharedSupport"

if [ ! -d "$SUPPORT_DIR" ]; then
  echo "SharedSupport directory not found: $SUPPORT_DIR" >&2
  exit 1
fi

# 移除官方内置的其他输入方案，但保留明月拼音依赖
find "$SUPPORT_DIR" -maxdepth 1 -type f \( -name "*.schema.yaml" -o -name "*.dict.yaml" \) \
  ! -name "luna_pinyin*" \
  -delete

cp -R "../../../$SCHEMA_DIR"/. "$SUPPORT_DIR"/

# 注入主题
if [ ! -f "$SUPPORT_DIR/squirrel.yaml" ]; then
  echo "$SUPPORT_DIR/squirrel.yaml not found" >&2
  exit 1
fi

python3 "../../../.ci/preset_color.py" \
  "$SUPPORT_DIR/squirrel.yaml" \
  "../../../theme/seedict.squirrel.yaml"

# 重新打包 Payload
rm -f Payload
(
  cd "$PAYLOAD_ROOT"
  find . | cpio -o --format odc | gzip -c > ../Payload
)

rm -rf "$PAYLOAD_ROOT"

popd >/dev/null

UNSIGNED_PKG="$OUTPUT_DIR/${PACKAGE_NAME}-squirrel-${SQUIRREL_VERSION}-unsigned.pkg"
pkgutil --flatten "$WORKDIR/package" "$UNSIGNED_PKG"

rm -f "$OUTPUT_DIR/$PKG_NAME"

echo "Built: $UNSIGNED_PKG"
