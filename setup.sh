#!/usr/bin/env bash
set -euo pipefail

MODE="symlink"
CHECK_ONLY=false
UNAME_S=$(uname -s 2>/dev/null || echo "unknown")

# VS Code settings destination depends on platform
VSCODE_DEST="$HOME/Library/Application Support/Code/User/settings.json"
if [[ "$UNAME_S" == "Linux" ]]; then
  VSCODE_DEST="$HOME/.config/Code/User/settings.json"
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --copy)
      MODE="copy"
      ;;
    --check)
      CHECK_ONLY=true
      ;;
    --help)
      cat <<'EOF'
Usage: ./setup.sh [--copy] [--check]

By default, creates symlinks from this repo to $HOME.
Use --copy to copy files instead of symlinking.
Use --check to run recommended environment checks without linking/copying.
Existing files are backed up with a timestamped .bak suffix.
EOF
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
  shift
done

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

backup_if_exists() {
  local target="$1"
  if [[ -e "$target" || -L "$target" ]]; then
    local backup="${target}.bak.$(date +%s)"
    mv "$target" "$backup"
    echo "Backed up $target -> $backup"
  fi
}

status_line() {
  local state="$1" label="$2" detail="${3:-}"
  if [[ -n "$detail" ]]; then
    printf "[%s] %s - %s\n" "$state" "$label" "$detail"
  else
    printf "[%s] %s\n" "$state" "$label"
  fi
}

check_cmd() {
  local cmd="$1" label="${2:-$1}"
  if command -v "$cmd" >/dev/null 2>&1; then
    status_line "OK" "$label" "$(command -v "$cmd")"
  else
    status_line "MISS" "$label" "not found"
  fi
}

check_path() {
  local path="$1" label="${2:-$1}"
  if [[ -e "$path" ]]; then
    status_line "OK" "$label" "$path"
  else
    status_line "MISS" "$label" "missing"
  fi
}

check_font() {
  local font_name="$1"
  for dir in "$HOME/Library/Fonts" "/Library/Fonts"; do
    if compgen -G "$dir/${font_name}*" > /dev/null 2>&1; then
      status_line "OK" "Font $font_name" "$dir"
      return 0
    fi
  done
  status_line "WARN" "Font $font_name" "not found (install recommended)"
  return 1
}

run_checks() {
  local bg_path="$HOME/Downloads/jayce-arcane-survivor-skin-lol-splash-art-2k-wallpaper-uhdpaper.com-433@3@b.jpg"

  echo "== Paths =="
  check_path "$HOME/.oh-my-zsh" "oh-my-zsh"
  check_path "/opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" "zsh-syntax-highlighting (Homebrew path)"
  check_path "$HOME/.p10k.zsh" "powerlevel10k config (optional)"
  check_path "$HOME/.nvm" "nvm directory"
  check_path "$HOME/.config/aerospace" "AeroSpace config"
  check_path "$HOME/.wezterm.lua" "WezTerm config"
  check_path "$HOME/.zshrc" "zshrc"
  check_path "$(dirname "$VSCODE_DEST")" "VS Code user dir"
  check_path "$bg_path" "WezTerm background (optional)"

  echo "== Commands =="
  for cmd in git zsh eza zoxide pnpm docker code wezterm; do
    check_cmd "$cmd"
  done
  check_cmd "aerospace" "aerospace (wm cli)"
  check_cmd "claude" "claude cli (optional)"
  check_cmd "codex" "codex cli (optional)"
  check_cmd "gemini" "gemini cli (optional)"
  check_cmd "lms" "lm studio cli (optional)"

  echo "== Fonts =="
  check_font "Fira Code"
}

ensure_fira_code() {
  if check_font "Fira Code"; then
    return
  fi

  if [[ "$CHECK_ONLY" == true ]]; then
    return
  fi

  if command -v brew >/dev/null 2>&1; then
    status_line "ACTION" "Font Fira Code" "installing via Homebrew"
    if brew tap homebrew/cask-fonts >/dev/null 2>&1 && brew install --cask font-fira-code >/dev/null 2>&1; then
      status_line "OK" "Font Fira Code" "installed via Homebrew"
    else
      status_line "FAIL" "Font Fira Code" "Homebrew install failed; install manually"
    fi
    return
  fi

  if command -v apt-get >/dev/null 2>&1; then
    status_line "ACTION" "Font Fira Code" "installing via apt-get (fonts-firacode)"
    if sudo apt-get update -y >/dev/null 2>&1 && sudo apt-get install -y fonts-firacode >/dev/null 2>&1; then
      status_line "OK" "Font Fira Code" "installed via apt-get"
    else
      status_line "FAIL" "Font Fira Code" "apt-get install failed; install manually"
    fi
    return
  else
    status_line "MISS" "Homebrew" "required to auto-install Fira Code"
  fi

  status_line "WARN" "Font Fira Code" "install manually: https://fonts.google.com/specimen/Fira+Code"
}

link_or_copy() {
  local src="$1"
  local dest="$2"
  mkdir -p "$(dirname "$dest")"
  backup_if_exists "$dest"

  if [[ "$MODE" == "copy" ]]; then
    cp -R "$src" "$dest"
    echo "Copied $src -> $dest"
  else
    ln -s "$src" "$dest"
    echo "Linked $src -> $dest"
  fi
}

TARGETS=(
  ".zshrc|$HOME/.zshrc"
  "my_custom.zsh|$HOME/.oh-my-zsh/custom/my_custom.zsh"
  "aerospace.toml|$HOME/.config/aerospace/aerospace.toml"
  ".wezterm.lua|$HOME/.wezterm.lua"
  ".vscode/settings.json|$VSCODE_DEST"
)

if [[ "$CHECK_ONLY" == true ]]; then
  run_checks
  exit 0
fi

ensure_fira_code

for entry in "${TARGETS[@]}"; do
  IFS='|' read -r rel dest <<< "$entry"
  src="$ROOT/$rel"
  if [[ ! -e "$src" && ! -L "$src" ]]; then
    echo "Skipping missing $src" >&2
    continue
  fi
  link_or_copy "$src" "$dest"
done

echo "Setup complete using mode: $MODE"
