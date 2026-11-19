#!/usr/bin/env bash
set -euo pipefail

ZSH_CUSTOM_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

get_login_shell() {
  local login_shell=""
  if [[ "$OS" == "macos" ]] && command -v dscl >/dev/null 2>&1; then
    login_shell="$(dscl . -read "/Users/$USER" UserShell 2>/dev/null | awk '{print $2}' || true)"
  elif command -v getent >/dev/null 2>&1; then
    login_shell="$(getent passwd "$USER" 2>/dev/null | cut -d: -f7 || true)"
  fi
  echo "${login_shell:-${SHELL:-}}"
}

find_zsh_plugin() {
  local plugin="$1" file="$2"
  local candidates=(
    "/opt/homebrew/share/$plugin/$file"
    "/usr/local/share/$plugin/$file"
    "/usr/share/$plugin/$file"
    "/usr/share/zsh/plugins/$plugin/$file"
    "$ZSH_CUSTOM_DIR/plugins/$plugin/$file"
  )
  local p
  for p in "${candidates[@]}"; do
    if [[ -r "$p" ]]; then
      echo "$p"
      return 0
    fi
  done
  return 1
}

find_zsh_completions() {
  local candidates=(
    "$ZSH_CUSTOM_DIR/plugins/zsh-completions/src"
    "/opt/homebrew/share/zsh-completions"
    "/usr/local/share/zsh-completions"
  )
  local p
  for p in "${candidates[@]}"; do
    if [[ -d "$p" ]]; then
      echo "$p"
      return 0
    fi
  done
  return 1
}

ensure_zsh() {
  if command -v zsh >/dev/null 2>&1; then
    status_line "OK" "zsh" "$(command -v zsh)"
    return
  fi
  if ! pkg_install "zsh" "zsh" "zsh" "zsh"; then
    status_line "FAIL" "zsh" "auto-install failed; please install zsh manually"
  fi
}

ensure_oh_my_zsh() {
  if [[ -r "$HOME/.oh-my-zsh/oh-my-zsh.sh" ]]; then
    status_line "OK" "oh-my-zsh" "$HOME/.oh-my-zsh"
    return
  fi
  if ! command -v git >/dev/null 2>&1; then
    status_line "WARN" "oh-my-zsh" "git not found; skipping install"
    return
  fi

  status_line "ACTION" "oh-my-zsh" "installing into $HOME/.oh-my-zsh"
  if [[ -d "$HOME/.oh-my-zsh" ]]; then
    # Preserve existing custom/ (plugins/symlinks) if an earlier run created ~/.oh-my-zsh/custom
    local tmp_omz
    tmp_omz="$(mktemp -d)"
    if git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git "$tmp_omz" >/dev/null 2>&1; then
      if [[ -d "$HOME/.oh-my-zsh/custom" ]]; then
        cp -a "$HOME/.oh-my-zsh/custom/." "$tmp_omz/custom/"
      fi
      local backup="$HOME/.oh-my-zsh.bak.$(date +%s)"
      mv "$HOME/.oh-my-zsh" "$backup"
      mv "$tmp_omz" "$HOME/.oh-my-zsh"
      rm -rf "$backup"
      status_line "OK" "oh-my-zsh" "$HOME/.oh-my-zsh (preserved existing custom/)"
    else
      rm -rf "$tmp_omz"
      status_line "FAIL" "oh-my-zsh" "clone failed; install manually from https://ohmyz.sh"
    fi
  else
    if git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git "$HOME/.oh-my-zsh" >/dev/null 2>&1; then
      status_line "OK" "oh-my-zsh" "$HOME/.oh-my-zsh"
    else
      status_line "FAIL" "oh-my-zsh" "clone failed; install manually from https://ohmyz.sh"
    fi
  fi
}

install_zsh_custom_plugin() {
  local name="$1" repo="$2"
  local dest="$ZSH_CUSTOM_DIR/plugins/$name"
  if [[ -d "$dest" ]]; then
    status_line "OK" "$name" "$dest"
    return
  fi
  if ! command -v git >/dev/null 2>&1; then
    status_line "WARN" "$name" "git not found; skipping install"
    return
  fi
  mkdir -p "$ZSH_CUSTOM_DIR/plugins"
  status_line "ACTION" "$name" "cloning plugin"
  if git clone --depth=1 "$repo" "$dest" >/dev/null 2>&1; then
    status_line "OK" "$name" "$dest"
  else
    status_line "FAIL" "$name" "clone failed; install manually from $repo"
  fi
}

ensure_zsh_plugins() {
  local found=""
  if found="$(find_zsh_plugin "zsh-autosuggestions" "zsh-autosuggestions.zsh")"; then
    status_line "OK" "zsh-autosuggestions" "$found"
  else
    install_zsh_custom_plugin "zsh-autosuggestions" "https://github.com/zsh-users/zsh-autosuggestions.git"
  fi

  if found="$(find_zsh_completions)"; then
    status_line "OK" "zsh-completions" "$found"
  else
    install_zsh_custom_plugin "zsh-completions" "https://github.com/zsh-users/zsh-completions.git"
  fi

  if found="$(find_zsh_plugin "zsh-syntax-highlighting" "zsh-syntax-highlighting.zsh")"; then
    status_line "OK" "zsh-syntax-highlighting" "$found"
  else
    install_zsh_custom_plugin "zsh-syntax-highlighting" "https://github.com/zsh-users/zsh-syntax-highlighting.git"
  fi
}

ensure_default_shell() {
  local zsh_path
  zsh_path="$(command -v zsh 2>/dev/null || true)"
  if [[ -z "$zsh_path" ]]; then
    status_line "WARN" "Default shell" "zsh not installed; cannot set as default shell"
    return
  fi

  local current_shell
  current_shell="$(get_login_shell)"
  if [[ "$(basename "$current_shell" 2>/dev/null || true)" == "zsh" ]]; then
    status_line "OK" "Default shell" "$current_shell"
    return
  fi

  if [[ -r /etc/shells ]] && ! grep -Fxq "$zsh_path" /etc/shells; then
    status_line "ACTION" "/etc/shells" "adding $zsh_path"
    echo "$zsh_path" | run_sudo tee -a /etc/shells >/dev/null || true
  fi

  status_line "ACTION" "Default shell" "switching to $zsh_path"
  if [[ -t 0 ]] && command -v chsh >/dev/null 2>&1; then
    if chsh -s "$zsh_path"; then
      status_line "OK" "Default shell" "changed to $zsh_path (log out & log back in for desktop terminals to pick up \$SHELL)"
      return
    fi
  fi
  if [[ "$OS" == "linux" ]] && command -v usermod >/dev/null 2>&1; then
    if run_sudo usermod -s "$zsh_path" "$USER"; then
      status_line "OK" "Default shell" "changed to $zsh_path via usermod (log out & log back in for desktop terminals to pick up \$SHELL)"
      return
    fi
  fi

  status_line "WARN" "Default shell" "could not change automatically; run: chsh -s $zsh_path"
}

setup_module() {
  ensure_zsh
  ensure_oh_my_zsh
  ensure_zsh_plugins

  link_or_copy "$ROOT/zsh/.zshrc" "$HOME/.zshrc"
  link_or_copy "$ROOT/zsh/my_custom.zsh" "$ZSH_CUSTOM_DIR/my_custom.zsh"

  if [[ -e "$ROOT/zsh/work.zsh" || -L "$ROOT/zsh/work.zsh" ]]; then
    link_or_copy "$ROOT/zsh/work.zsh" "$ZSH_CUSTOM_DIR/work.zsh"
  else
    status_line "SKIP" "zsh/work.zsh" "optional local file not present"
  fi

  ensure_default_shell
}

check_module() {
  local current_shell
  current_shell="$(get_login_shell)"
  if [[ "$(basename "$current_shell" 2>/dev/null || true)" == "zsh" ]]; then
    status_line "OK" "Default shell" "$current_shell"
  else
    status_line "WARN" "Default shell" "${current_shell:-unknown} (run ./setup.sh to switch to zsh)"
  fi

  check_cmd "zsh"
  check_path "$HOME/.zshrc" "zshrc"
  check_path "$HOME/.oh-my-zsh/oh-my-zsh.sh" "oh-my-zsh"
  check_path "$ZSH_CUSTOM_DIR/work.zsh" "work.zsh (optional local)"

  local found=""
  if found="$(find_zsh_plugin "zsh-autosuggestions" "zsh-autosuggestions.zsh")"; then
    status_line "OK" "zsh-autosuggestions" "$found"
  else
    status_line "MISS" "zsh-autosuggestions" "missing"
  fi
  if found="$(find_zsh_completions)"; then
    status_line "OK" "zsh-completions" "$found"
  else
    status_line "MISS" "zsh-completions" "missing"
  fi
  if found="$(find_zsh_plugin "zsh-syntax-highlighting" "zsh-syntax-highlighting.zsh")"; then
    status_line "OK" "zsh-syntax-highlighting" "$found"
  else
    status_line "MISS" "zsh-syntax-highlighting" "missing"
  fi

  check_path "$HOME/.p10k.zsh" "powerlevel10k config (optional)"
  check_path "$HOME/.nvm" "nvm directory"

  local cmd
  for cmd in eza zoxide pnpm docker; do
    check_cmd "$cmd"
  done
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"
  run_standalone_module "$@"
fi
