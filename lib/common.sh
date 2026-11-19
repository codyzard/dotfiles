#!/usr/bin/env bash
# Shared helpers for root setup.sh orchestrator and colocated <app>/setup.sh modules.

if [[ -n "${DOTFILES_COMMON_LOADED:-}" ]]; then
  return 0 2>/dev/null || true
fi
DOTFILES_COMMON_LOADED=1

ROOT="${ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
MODE="${MODE:-symlink}"
CHECK_ONLY="${CHECK_ONLY:-false}"
INSTALL_MISSING="${INSTALL_MISSING:-false}"

UNAME_S=$(uname -s 2>/dev/null || echo "unknown")
case "$UNAME_S" in
  Darwin) OS="macos" ;;
  Linux)  OS="linux" ;;
  *)      OS="other" ;;
esac

status_line() {
  local state="$1" label="$2" detail="${3:-}"
  if [[ -n "$detail" ]]; then
    printf "[%s] %s - %s\n" "$state" "$label" "$detail"
  else
    printf "[%s] %s\n" "$state" "$label"
  fi
}

run_sudo() {
  if [[ -t 0 ]]; then
    sudo "$@"
  else
    sudo -n "$@"
  fi
}

# Install a package using the available OS package manager.
# Pass "-" to skip a package manager; prefix brew_pkg with "--cask " for casks.
pkg_install() {
  local label="$1" brew_pkg="$2" dnf_pkg="$3" apt_pkg="$4"

  if [[ "$OS" == "macos" && "$brew_pkg" != "-" ]] && command -v brew >/dev/null 2>&1; then
    status_line "ACTION" "$label" "installing via Homebrew ($brew_pkg)"
    # shellcheck disable=SC2086
    if brew install $brew_pkg >/dev/null 2>&1; then
      status_line "OK" "$label" "installed via Homebrew"
      return 0
    fi
    status_line "FAIL" "$label" "Homebrew install failed"
    return 1
  fi

  if [[ "$dnf_pkg" != "-" ]] && command -v dnf >/dev/null 2>&1; then
    status_line "ACTION" "$label" "installing via dnf ($dnf_pkg)"
    if run_sudo dnf install -y "$dnf_pkg"; then
      status_line "OK" "$label" "installed via dnf"
      return 0
    fi
    status_line "FAIL" "$label" "dnf install failed"
    return 1
  fi

  if [[ "$apt_pkg" != "-" ]] && command -v apt-get >/dev/null 2>&1; then
    status_line "ACTION" "$label" "installing via apt-get ($apt_pkg)"
    if run_sudo apt-get update -y && run_sudo apt-get install -y "$apt_pkg"; then
      status_line "OK" "$label" "installed via apt-get"
      return 0
    fi
    status_line "FAIL" "$label" "apt-get install failed"
    return 1
  fi

  return 1
}

backup_if_exists() {
  local target="$1"
  if [[ -e "$target" || -L "$target" ]]; then
    local backup="${target}.bak.$(date +%s)"
    mv "$target" "$backup"
    echo "Backed up $target -> $backup"
  fi
}

link_or_copy() {
  local src="$1" dest="$2"
  # Idempotent: skip if already symlinked to src (avoids .bak clutter on re-runs)
  if [[ "$MODE" == "symlink" && "$(readlink "$dest" 2>/dev/null || true)" == "$src" ]]; then
    echo "Already linked: $dest"
    return
  fi
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

check_cmd() {
  local cmd="$1" label="${2:-$1}"
  if command -v "$cmd" >/dev/null 2>&1; then
    status_line "OK" "$label" "$(command -v "$cmd")"
  elif [[ "$OS" == "macos" && "$cmd" == "ghostty" && -d "/Applications/Ghostty.app" ]]; then
    status_line "OK" "$label" "/Applications/Ghostty.app"
  elif [[ "$OS" == "macos" && "$cmd" == "wezterm" && -d "/Applications/WezTerm.app" ]]; then
    status_line "OK" "$label" "/Applications/WezTerm.app"
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
  if [[ "$OS" == "macos" ]]; then
    local dir
    for dir in "$HOME/Library/Fonts" "/Library/Fonts"; do
      if [[ -d "$dir" ]] && find "$dir" -maxdepth 2 -iname "*fira*code*" -print -quit 2>/dev/null | grep -q .; then
        status_line "OK" "Font $font_name" "$dir"
        return 0
      fi
    done
  else
    if command -v fc-list >/dev/null 2>&1; then
      if fc-list : family 2>/dev/null | grep -qi "$font_name"; then
        status_line "OK" "Font $font_name" "found via fc-list"
        return 0
      fi
    fi
    local dir
    for dir in "$HOME/.local/share/fonts" "/usr/share/fonts" "/usr/local/share/fonts"; do
      if [[ -d "$dir" ]] && find "$dir" -maxdepth 3 -iname "*fira*code*" -print -quit 2>/dev/null | grep -q .; then
        status_line "OK" "Font $font_name" "$dir"
        return 0
      fi
    done
  fi
  status_line "WARN" "Font $font_name" "not found (install recommended)"
  return 1
}

ensure_fira_code() {
  if check_font "Fira Code"; then
    return
  fi
  if [[ "$CHECK_ONLY" == true ]]; then
    return
  fi
  if ! pkg_install "Font Fira Code" "--cask font-fira-code" "fira-code-fonts" "fonts-firacode"; then
    status_line "WARN" "Font Fira Code" "install manually: https://fonts.google.com/specimen/Fira+Code"
  fi
}

install_optional_cli() {
  local cmd="$1" friendly="$2" brew_arg="$3" linux_hint="$4"
  if command -v "$cmd" >/dev/null 2>&1 || [[ "$OS" == "macos" && "$cmd" == "ghostty" && -d "/Applications/Ghostty.app" ]]; then
    return
  fi
  if [[ "$CHECK_ONLY" == true || "$INSTALL_MISSING" != true ]]; then
    return
  fi
  if [[ "$OS" == "macos" ]] && command -v brew >/dev/null 2>&1 && [[ "$brew_arg" != "manual" ]]; then
    status_line "ACTION" "$friendly" "installing via Homebrew"
    # shellcheck disable=SC2086
    if brew install $brew_arg >/dev/null 2>&1; then
      status_line "OK" "$friendly" "installed via Homebrew"
      return
    else
      status_line "FAIL" "$friendly" "Homebrew install failed; install manually ($linux_hint)"
      return
    fi
  fi
  status_line "INFO" "$friendly" "install manually: $linux_hint"
}

# Allows any colocated <app>/setup.sh to be executed directly as a standalone script.
run_standalone_module() {
  local arg
  for arg in "$@"; do
    case "$arg" in
      --copy) MODE="copy" ;;
      --check) CHECK_ONLY=true ;;
      --install-missing) INSTALL_MISSING=true ;;
      --help)
        echo "Usage: $0 [--copy] [--check] [--install-missing]"
        exit 0
        ;;
      *)
        echo "Unknown option: $arg" >&2
        exit 1
        ;;
    esac
  done

  if [[ "$CHECK_ONLY" == true ]]; then
    check_module
  else
    setup_module
  fi
}
