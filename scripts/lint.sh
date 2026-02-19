#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

echo "=== Running HLint ==="
hlint exercises/ --hint=.hlint.yaml

echo ""
echo "=== Checking Fourmolu formatting ==="
find exercises/ -name '*.hs' -not -path '*/.stack-work/*' | xargs fourmolu --mode check --ghc-opt=-XImportQualifiedPost

echo ""
echo "All checks passed!"
