#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

echo "==> Building all exercise packages..."
stack build

echo "==> Building book..."
mdbook build

echo "==> Done."
