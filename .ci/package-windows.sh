#!/usr/bin/env bash
set -euo pipefail

SCHEMA_DIR="${SCHEMA_DIR:-rime}"
OUTPUT_DIR="${OUTPUT_DIR:-output}"

PACKAGE_NAME="rime-hokchew"

mkdir -p "$OUTPUT_DIR"

# 注入安装包默认启用方案配置
bash .ci/prepare-schema.sh

WEASEL_VERSION="$(gh release view --repo rime/weasel --json tagName --jq .tagName)"
WEASEL_VERSION="${WEASEL_VERSION#v}"

INSTALLER="weasel-${WEASEL_VERSION}.0-installer.exe"
INSTALLER_URL="https://github.com/rime/weasel/releases/download/${WEASEL_VERSION}/${INSTALLER}"

echo "Using Weasel version: $WEASEL_VERSION"
echo "Downloading: $INSTALLER_URL"

curl -L "$INSTALLER_URL" -o "$OUTPUT_DIR/$INSTALLER"

rm -rf "$OUTPUT_DIR/weasel"
7z x "$OUTPUT_DIR/$INSTALLER" -aou -o"$OUTPUT_DIR/weasel"

pushd "$OUTPUT_DIR/weasel" >/dev/null

mkdir -p Win32

for file in *_1.*; do
  if [ ! -e "$file" ]; then
    continue
  fi

  extension="${file##*.}"
  base_file="${file%_1.*}.$extension"

  if [ ! -f "$base_file" ]; then
    echo "Base file not found for $file: $base_file" >&2
    continue
  fi

  if file "$base_file" | grep -q "x86-64"; then
    :
  else
    mv "$base_file" "Win32/$base_file"
  fi

  if file "$file" | grep -q "x86-64"; then
    mv "$file" "$base_file"
  else
    mv "$file" "Win32/$base_file"
  fi
done

if [ ! -f "Win32/WeaselDeployer.exe" ]; then
  echo "Win32/WeaselDeployer.exe not found after arranging files" >&2
  echo "Current directory files:" >&2
  find . -maxdepth 2 -name "WeaselDeployer.exe" -print >&2
  exit 1
fi

# 移除官方内置的其他输入方案，但保留明月拼音依赖
find data -maxdepth 1 -type f \( -name "*.schema.yaml" -o -name "*.dict.yaml" \) \
  ! -name "luna_pinyin*" \
  -delete

cp -R "../../$SCHEMA_DIR"/. data/

curl -L "https://raw.githubusercontent.com/rime/weasel/${WEASEL_VERSION}/output/install.nsi" -o install.nsi
mkdir -p ../resource
curl -L "https://raw.githubusercontent.com/rime/weasel/${WEASEL_VERSION}/resource/weasel.ico" -o ../resource/weasel.ico

mkdir -p archives

MAKENSIS="${MAKENSIS:-}"

if [ -z "$MAKENSIS" ]; then
  if command -v makensis.exe >/dev/null 2>&1; then
    MAKENSIS="makensis.exe"
  elif command -v makensis >/dev/null 2>&1; then
    MAKENSIS="makensis"
  elif [ -x "/c/Program Files (x86)/NSIS/makensis.exe" ]; then
    MAKENSIS="/c/Program Files (x86)/NSIS/makensis.exe"
  elif [ -x "/c/Program Files/NSIS/makensis.exe" ]; then
    MAKENSIS="/c/Program Files/NSIS/makensis.exe"
  else
    echo "makensis not found" >&2
    exit 1
  fi
fi

echo "Using makensis: $MAKENSIS"

"$MAKENSIS" \
  //DWEASEL_VERSION="$WEASEL_VERSION" \
  //DPRODUCT_VERSION="$WEASEL_VERSION" \
  install.nsi

popd >/dev/null

FOUND_INSTALLER="$(find "$OUTPUT_DIR/weasel/archives" -maxdepth 1 -name "weasel-*.exe" | head -n 1)"

if [ -z "$FOUND_INSTALLER" ]; then
  echo "Failed to find generated Weasel installer" >&2
  exit 1
fi

FINAL_NAME="${PACKAGE_NAME}-weasel-${WEASEL_VERSION}.exe"
mv "$FOUND_INSTALLER" "$OUTPUT_DIR/$FINAL_NAME"

rm -f "$OUTPUT_DIR/$INSTALLER"

echo "Built: $OUTPUT_DIR/$FINAL_NAME"
