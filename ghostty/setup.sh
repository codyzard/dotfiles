#!/usr/bin/env bash
set -euo pipefail

setup_module() {
  install_optional_cli "ghostty" "ghostty terminal" "--cask ghostty" "https://ghostty.org/docs/install"
  link_or_copy "$ROOT/ghostty/config" "$HOME/.config/ghostty/config"
}

check_module() {
  check_path "$HOME/.config/ghostty/config" "Ghostty config"
  check_cmd "ghostty"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"
  run_standalone_module "$@"
fi
