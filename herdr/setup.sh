#!/usr/bin/env bash
set -euo pipefail

setup_module() {
  link_or_copy "$ROOT/herdr/config.toml" "$HOME/.config/herdr/config.toml"
}

check_module() {
  check_path "$HOME/.config/herdr/config.toml" "Herdr config"
  check_cmd "herdr" "herdr cli (optional)"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"
  run_standalone_module "$@"
fi
