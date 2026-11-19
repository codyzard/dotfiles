#!/usr/bin/env bash
set -euo pipefail

vscode_dest() {
  if [[ "$OS" == "macos" ]]; then
    echo "$HOME/Library/Application Support/Code/User/settings.json"
  else
    echo "$HOME/.config/Code/User/settings.json"
  fi
}

setup_module() {
  link_or_copy "$ROOT/.vscode/settings.json" "$(vscode_dest)"
}

check_module() {
  local dest
  dest="$(vscode_dest)"
  check_path "$(dirname "$dest")" "VS Code user dir"
  check_path "$dest" "VS Code settings.json"
  check_cmd "code"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"
  run_standalone_module "$@"
fi
