#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

echo "==> Preparing exercises (clearing MySolutions.hs in all chapters)..."

for f in exercises/chapter*/test/MySolutions.hs; do
  if [ -f "$f" ]; then
    module_name=$(head -1 "$f" | grep -oP '(?<=module )\w+' || echo "MySolutions")
    cat > "$f" <<EOF
module ${module_name} where

-- Здесь вы можете писать свои решения упражнений.
EOF
    echo "  Cleared: $f"
  fi
done

echo "==> Done."
