#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$ROOT/lib/common.sh"

# Ordered list of colocated app modules (each provides <module>/setup.sh)
MODULES=(
  git
  zsh
  ghostty
  herdr
  wezterm
  aerospace
  browser
  gnome
  .vscode
)

SELECTED_MODULES=()

usage() {
  cat <<'EOF'
Usage: ./setup.sh [options]

Orchestrates colocated <app>/setup.sh modules across macOS and Linux.

Options:
  --copy             Copy files instead of creating symlinks
  --check            Run environment checks without modifying anything
  --install-missing  Attempt installing optional CLIs when absent
  --only <module>    Run only the specified module (repeatable, e.g. --only zsh --only gnome)
  --list             List available modules and exit
  --help             Show this help message

You can also run any module directly, e.g.:
  ./gnome/setup.sh
  ./zsh/setup.sh --check
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --copy)
      MODE="copy"
      ;;
    --check)
      CHECK_ONLY=true
      ;;
    --install-missing)
      INSTALL_MISSING=true
      ;;
    --only)
      if [[ $# -lt 2 ]]; then
        echo "--only requires a module name" >&2
        exit 1
      fi
      SELECTED_MODULES+=("$2")
      shift
      ;;
    --list)
      printf '%s\n' "${MODULES[@]}"
      exit 0
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

if [[ ${#SELECTED_MODULES[@]} -eq 0 ]]; then
  ACTIVE_MODULES=("${MODULES[@]}")
  FULL_RUN=true
else
  ACTIVE_MODULES=("${SELECTED_MODULES[@]}")
  FULL_RUN=false
fi

run_module() {
  local mod="$1" action="$2"
  local script="$ROOT/$mod/setup.sh"
  if [[ ! -r "$script" ]]; then
    echo "Unknown module '$mod' (missing $script)" >&2
    exit 1
  fi

  echo "== [$mod] =="
  unset -f setup_module check_module 2>/dev/null || true
  # shellcheck disable=SC1090
  source "$script"
  if [[ "$action" == "check" ]]; then
    check_module
  else
    setup_module
  fi
}

check_shared() {
  echo "== [shared] =="
  check_cmd "claude" "claude cli (optional)"
  check_cmd "codex" "codex cli (optional)"
  check_cmd "gemini" "gemini cli (optional)"
  check_cmd "lms" "lm studio cli (optional)"
  check_font "Fira Code" || true
}

setup_shared() {
  echo "== [shared] =="
  ensure_fira_code
  for opt in \
    "claude|claude cli|--cask claude-code|npm install -g @anthropic-ai/claude-code" \
    "codex|codex cli|--cask codex|npm install -g @openai/codex" \
    "gemini|gemini cli|gemini-cli|npm install -g @google/gemini-cli" \
    "lms|lm studio cli|manual|https://lmstudio.ai/docs/cli"
  do
    IFS='|' read -r cmd friendly brew_arg linux_hint <<< "$opt"
    install_optional_cli "$cmd" "$friendly" "$brew_arg" "$linux_hint"
  done
}

echo "== System: $OS ($UNAME_S) =="

if [[ "$CHECK_ONLY" == true ]]; then
  for mod in "${ACTIVE_MODULES[@]}"; do
    run_module "$mod" "check"
  done
  [[ "$FULL_RUN" == true ]] && check_shared
  exit 0
fi

[[ "$FULL_RUN" == true ]] && setup_shared

for mod in "${ACTIVE_MODULES[@]}"; do
  run_module "$mod" "setup"
done

echo "Setup complete ($OS) using mode: $MODE"
