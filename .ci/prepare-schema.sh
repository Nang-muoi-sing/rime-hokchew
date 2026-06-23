#!/usr/bin/env bash
set -euo pipefail

SCHEMA_DIR="${SCHEMA_DIR:-schema}"

if [ ! -d "$SCHEMA_DIR" ]; then
  echo "Schema directory not found: $SCHEMA_DIR" >&2
  exit 1
fi

cat > "$SCHEMA_DIR/default.custom.yaml" <<'EOF'
patch:
  schema_list:
    - schema: hukziu
    - schema: hukziu_roma
    - schema: yngping
EOF
