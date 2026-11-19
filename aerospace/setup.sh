#!/usr/bin/env bash
set -euo pipefail

setup_module() {
  if [[ "$OS" != "macos" ]]; then
    status_line "SKIP" "aerospace/aerospace.toml" "macos only"
    return
  fi
  link_or_copy "$ROOT/aerospace/aerospace.toml" "$HOME/.config/aerospace/aerospace.toml"
}

check_module() {
  if [[ "$OS" != "macos" ]]; then
    status_line "SKIP" "AeroSpace" "macOS only"
    return
  fi
  check_path "$HOME/.config/aerospace/aerospace.toml" "AeroSpace config"
  check_cmd "aerospace" "aerospace (wm cli)"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"
  run_standalone_module "$@"
fi
