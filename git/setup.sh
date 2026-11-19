#!/usr/bin/env bash
set -euo pipefail

setup_module() {
  link_or_copy "$ROOT/git/.gitconfig" "$HOME/.gitconfig"
}

check_module() {
  check_path "$HOME/.gitconfig" "git config"
  check_cmd "git"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"
  run_standalone_module "$@"
fi
