#!/usr/bin/env bash
set -euo pipefail

find_firefox_profile_dirs() {
  local roots=()
  if [[ "$OS" == "macos" ]]; then
    roots=("$HOME/Library/Application Support/Firefox")
  else
    roots=(
      "$HOME/.config/mozilla/firefox"
      "$HOME/.mozilla/firefox"
      "$HOME/.var/app/org.mozilla.firefox/config/mozilla/firefox"
      "$HOME/.var/app/org.mozilla.firefox/.mozilla/firefox"
    )
  fi

  local root ini section line rel_path candidate found_any
  for root in "${roots[@]}"; do
    ini="$root/profiles.ini"
    [[ -r "$ini" ]] || continue

    found_any=false
    section=""
    while IFS= read -r line || [[ -n "$line" ]]; do
      line="${line%$'\r'}"
      if [[ "$line" == \[*\] ]]; then
        section="$line"
        continue
      fi
      if [[ "$section" == \[Install*\] && "$line" == Default=* ]]; then
        rel_path="${line#Default=}"
        if [[ "$rel_path" == /* ]]; then
          candidate="$rel_path"
        else
          candidate="$root/$rel_path"
        fi
        if [[ -d "$candidate" ]]; then
          printf '%s\n' "$candidate"
          found_any=true
        fi
      fi
    done < "$ini"

    if [[ "$found_any" == true ]]; then
      continue
    fi

    for candidate in "$root"/*.default-release "$root"/*.default "$root"/Profiles/*.default-release "$root"/Profiles/*.default; do
      if [[ -d "$candidate" ]]; then
        printf '%s\n' "$candidate"
        break
      fi
    done
  done
}

ensure_firefox_user_js() {
  local src="$ROOT/browser/firefox/user.js"
  [[ -r "$src" ]] || return

  local profile_dir found=false
  while IFS= read -r profile_dir; do
    [[ -n "$profile_dir" ]] || continue
    found=true
    link_or_copy "$src" "$profile_dir/user.js"
  done < <(find_firefox_profile_dirs | awk '!seen[$0]++')

  if [[ "$found" == false ]]; then
    status_line "SKIP" "Firefox user.js" "no Firefox profile found"
  fi
}

setup_module() {
  link_or_copy "$ROOT/browser/tabgroups_rules.json" "$HOME/.config/tabgroups_rules.json"
  ensure_firefox_user_js
}

check_module() {
  check_path "$HOME/.config/tabgroups_rules.json" "Tab Groups rules (optional)"
  local ff_profile ff_found=false
  while IFS= read -r ff_profile; do
    [[ -n "$ff_profile" ]] || continue
    ff_found=true
    check_path "$ff_profile/user.js" "Firefox user.js"
  done < <(find_firefox_profile_dirs | awk '!seen[$0]++')
  if [[ "$ff_found" == false ]]; then
    status_line "SKIP" "Firefox user.js" "no Firefox profile found"
  fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"
  run_standalone_module "$@"
fi
