#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

echo "=== Formatting with Fourmolu ==="
find exercises/ -name '*.hs' -not -path '*/.stack-work/*' | xargs fourmolu --mode inplace --ghc-opt=-XImportQualifiedPost

echo "Done! All .hs files formatted."
