#!/usr/bin/env bash
set -euo pipefail

WEZTERM_WALLPAPER_DEST="$HOME/.config/wallpapers/wezterm-bg.jpeg"
WEZTERM_WALLPAPER_URL="https://raw.githubusercontent.com/JaKooLit/Wallpaper-Bank/main/wallpapers/Anime%20-%20Landscape.jpeg"

ensure_wezterm_wallpaper() {
  if [[ -e "$WEZTERM_WALLPAPER_DEST" ]]; then
    status_line "OK" "WezTerm wallpaper" "$WEZTERM_WALLPAPER_DEST"
    return
  fi
  if ! command -v curl >/dev/null 2>&1; then
    status_line "WARN" "WezTerm wallpaper" "curl not found; skipping download"
    return
  fi
  mkdir -p "$(dirname "$WEZTERM_WALLPAPER_DEST")"
  status_line "ACTION" "WezTerm wallpaper" "downloading"
  if curl -fsSL "$WEZTERM_WALLPAPER_URL" -o "$WEZTERM_WALLPAPER_DEST"; then
    status_line "OK" "WezTerm wallpaper" "$WEZTERM_WALLPAPER_DEST"
  else
    rm -f "$WEZTERM_WALLPAPER_DEST"
    status_line "FAIL" "WezTerm wallpaper" "download failed; set manually in .wezterm.lua"
  fi
}

setup_module() {
  ensure_wezterm_wallpaper
  link_or_copy "$ROOT/wezterm/.wezterm.lua" "$HOME/.wezterm.lua"
}

check_module() {
  check_path "$HOME/.wezterm.lua" "WezTerm config"
  check_path "$WEZTERM_WALLPAPER_DEST" "WezTerm background (optional)"
  check_cmd "wezterm"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"
  run_standalone_module "$@"
fi
