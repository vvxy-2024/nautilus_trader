#!/usr/bin/env bash
set -eo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"

cd "$repo_root"

# Best-effort local setup for contributors using this workspace template.
if command -v pre-commit >/dev/null 2>&1; then
  pre-commit install
fi
