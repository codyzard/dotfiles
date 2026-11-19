#!/usr/bin/env bash
set -euo pipefail

# Linux / GNOME Wayland desktop setup:
# - wl-clipboard
# - Vicinae launcher + systemd service + Alt+Space shortcut + GNOME extension (ID 8594)
# - GhostShot instant area screenshot GNOME extension (ID 9786) + GNOME 51/Mutter patch + Super+Shift+S
# - GNOME power shortcuts (Ctrl+Alt+Q suspend, Ctrl+Alt+L log out)

check_gnome_ext_pattern() {
  local pattern="$1"
  if command -v gnome-extensions >/dev/null 2>&1; then
    if gnome-extensions list 2>/dev/null | grep -qi "$pattern"; then
      return 0
    fi
  fi
  local dir
  for dir in "$HOME/.local/share/gnome-shell/extensions" "/usr/share/gnome-shell/extensions"; do
    if [[ -d "$dir" ]] && find "$dir" -maxdepth 1 -iname "*${pattern}*" -print -quit 2>/dev/null | grep -q .; then
      return 0
    fi
  done
  return 1
}

add_gnome_custom_keybinding() {
  local slug="$1" name="$2" cmd="$3" binding="$4"
  if ! command -v gsettings >/dev/null 2>&1; then
    return 1
  fi
  if ! gsettings list-schemas 2>/dev/null | grep -qx "org.gnome.settings-daemon.plugins.media-keys"; then
    return 1
  fi

  local kb_path="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/${slug}/"
  local schema="org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:${kb_path}"
  local current cur_binding cur_cmd cur_name
  current="$(gsettings get org.gnome.settings-daemon.plugins.media-keys custom-keybindings 2>/dev/null || echo "@as []")"
  cur_binding="$(gsettings get "$schema" binding 2>/dev/null || true)"
  cur_cmd="$(gsettings get "$schema" command 2>/dev/null || true)"
  cur_name="$(gsettings get "$schema" name 2>/dev/null || true)"

  if [[ "$current" == *"'$kb_path'"* \
     && "$cur_binding" == "'$binding'" \
     && "$cur_cmd" == "'$cmd'" \
     && "$cur_name" == "'$name'" ]]; then
    return 0
  fi

  if [[ "$current" != *"'$kb_path'"* ]]; then
    local updated
    if [[ "$current" == "@as []" || "$current" == "[]" ]]; then
      updated="['$kb_path']"
    else
      updated="${current%]}, '$kb_path']"
    fi
    gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "$updated" 2>/dev/null || return 1
  fi

  gsettings set "$schema" name "$name" 2>/dev/null || return 1
  gsettings set "$schema" command "$cmd" 2>/dev/null || return 1
  gsettings set "$schema" binding "$binding" 2>/dev/null || return 1
  return 0
}

remove_gnome_custom_keybinding() {
  local slug="$1"
  command -v gsettings >/dev/null 2>&1 || return 0
  local kb_path="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/${slug}/"
  local current
  current="$(gsettings get org.gnome.settings-daemon.plugins.media-keys custom-keybindings 2>/dev/null || echo "@as []")"
  [[ "$current" == *"'$kb_path'"* ]] || return 0

  if command -v python3 >/dev/null 2>&1; then
    local updated
    updated="$(python3 -c "import ast,sys; items=ast.literal_eval(sys.argv[1]) if sys.argv[1] != '@as []' else []; items=[x for x in items if x != sys.argv[2]]; print('@as []' if not items else repr(items))" "$current" "$kb_path" 2>/dev/null || true)"
    if [[ -n "$updated" ]]; then
      gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "$updated" 2>/dev/null || true
    fi
  fi
}

enable_gnome_extension_uuid() {
  local uuid="$1"
  [[ -n "$uuid" ]] || return 1
  gnome-extensions enable "$uuid" >/dev/null 2>&1 || true
  if command -v gsettings >/dev/null 2>&1; then
    local enabled
    enabled="$(gsettings get org.gnome.shell enabled-extensions 2>/dev/null || echo "@as []")"
    if [[ "$enabled" != *"'$uuid'"* ]]; then
      local updated
      if [[ "$enabled" == "@as []" || "$enabled" == "[]" ]]; then
        updated="['$uuid']"
      else
        updated="${enabled%]}, '$uuid']"
      fi
      gsettings set org.gnome.shell enabled-extensions "$updated" 2>/dev/null || true
    fi
  fi
}

install_gnome_extension_by_pk() {
  local pk="$1" pattern="$2" label="$3" url="$4"
  if ! command -v gnome-shell >/dev/null 2>&1 || ! command -v gnome-extensions >/dev/null 2>&1; then
    return
  fi

  local shell_ver
  shell_ver="$(gnome-shell --version 2>/dev/null | grep -oE '[0-9]+' | head -n1 || true)"

  if check_gnome_ext_pattern "$pattern"; then
    local existing_uuid=""
    existing_uuid="$(gnome-extensions list 2>/dev/null | grep -i "$pattern" | head -n1 || true)"
    if [[ -z "$existing_uuid" ]]; then
      local ext_dir
      ext_dir="$(find "$HOME/.local/share/gnome-shell/extensions" -maxdepth 1 -iname "*${pattern}*" -print -quit 2>/dev/null || true)"
      [[ -n "$ext_dir" ]] && existing_uuid="$(basename "$ext_dir")"
    fi
    [[ -n "$existing_uuid" ]] && enable_gnome_extension_uuid "$existing_uuid"
    status_line "OK" "$label" "${existing_uuid:-installed}"
    return
  fi

  if ! command -v curl >/dev/null 2>&1 || ! command -v python3 >/dev/null 2>&1; then
    status_line "INFO" "$label" "install $url manually"
    return
  fi

  status_line "ACTION" "$label" "downloading (ID $pk, GNOME ${shell_ver:-auto})"
  local meta_json ext_info uuid dl_url tmp_zip
  meta_json="$(curl -fsSL "https://extensions.gnome.org/extension-info/?pk=${pk}&shell_version=${shell_ver}" 2>/dev/null || true)"
  ext_info="$(printf '%s' "$meta_json" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('uuid',''), d.get('download_url',''))" 2>/dev/null || true)"
  read -r uuid dl_url <<< "$ext_info"

  # Fallback: extension hasn't listed the latest GNOME version yet -> pick highest supported version
  if [[ -z "$dl_url" ]]; then
    local base_json latest_ver
    base_json="$(curl -fsSL "https://extensions.gnome.org/extension-info/?pk=${pk}" 2>/dev/null || true)"
    latest_ver="$(printf '%s' "$base_json" | python3 -c "import json,sys; d=json.load(sys.stdin); vs=list(d.get('shell_version_map',{}).keys()); print(sorted(vs, key=lambda s:[int(x) for x in s.split('.') if x.isdigit()])[-1] if vs else '')" 2>/dev/null || true)"
    if [[ -n "$latest_ver" ]]; then
      meta_json="$(curl -fsSL "https://extensions.gnome.org/extension-info/?pk=${pk}&shell_version=${latest_ver}" 2>/dev/null || true)"
      ext_info="$(printf '%s' "$meta_json" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('uuid',''), d.get('download_url',''))" 2>/dev/null || true)"
      read -r uuid dl_url <<< "$ext_info"
    fi
  fi

  if [[ -z "$uuid" || -z "$dl_url" ]]; then
    status_line "WARN" "$label" "auto-download failed; install from $url"
    return
  fi

  tmp_zip="$(mktemp --suffix=.zip)"
  if curl -fsSL "https://extensions.gnome.org${dl_url}" -o "$tmp_zip" \
     && gnome-extensions install --force "$tmp_zip" >/dev/null 2>&1; then
    rm -f "$tmp_zip"
    local meta_file="$HOME/.local/share/gnome-shell/extensions/${uuid}/metadata.json"
    if [[ -n "$shell_ver" && -w "$meta_file" ]]; then
      python3 -c "import json,sys; p,v=sys.argv[1],sys.argv[2]; d=json.load(open(p)); sv=d.setdefault('shell-version',[]); (sv.append(v) if v not in sv else None); json.dump(d,open(p,'w'),indent=2)" "$meta_file" "$shell_ver" 2>/dev/null || true
    fi
    enable_gnome_extension_uuid "$uuid"
    status_line "OK" "$label" "installed ($uuid) — log out & log back in to activate"
  else
    rm -f "$tmp_zip"
    status_line "WARN" "$label" "install failed; install from $url"
  fi
}

ensure_wl_clipboard() {
  if command -v wl-copy >/dev/null 2>&1; then
    status_line "OK" "wl-clipboard" "$(command -v wl-copy)"
    return
  fi
  if ! pkg_install "wl-clipboard" "-" "wl-clipboard" "wl-clipboard"; then
    status_line "WARN" "wl-clipboard" "install wl-clipboard manually for Wayland clipboard support"
  fi
}

configure_vicinae_gnome_shortcut() {
  local vicinae_bin="$1"
  if ! command -v gsettings >/dev/null 2>&1 \
     || ! gsettings list-schemas 2>/dev/null | grep -qx "org.gnome.settings-daemon.plugins.media-keys"; then
    return
  fi

  local desired_cmd="${vicinae_bin} toggle"
  local cur_win_menu
  cur_win_menu="$(gsettings get org.gnome.desktop.wm.keybindings activate-window-menu 2>/dev/null || true)"
  if [[ "$cur_win_menu" != "@as []" && "$cur_win_menu" != "[]" ]]; then
    gsettings set org.gnome.desktop.wm.keybindings activate-window-menu "[]" 2>/dev/null || true
  fi

  if add_gnome_custom_keybinding "vicinae" "Toggle Vicinae" "$desired_cmd" "<Alt>space"; then
    status_line "OK" "Vicinae GNOME shortcut" "Alt+Space -> $desired_cmd"
  else
    status_line "WARN" "Vicinae GNOME shortcut" "could not update gsettings (no desktop session?)"
  fi
}

ensure_vicinae() {
  ensure_wl_clipboard

  local vicinae_bin
  vicinae_bin="$(command -v vicinae 2>/dev/null || true)"

  if [[ -z "$vicinae_bin" ]]; then
    if command -v dnf >/dev/null 2>&1; then
      status_line "ACTION" "Vicinae" "installing via Fedora Copr (dnf)"
      if run_sudo dnf copr enable -y scottames/vicinae && run_sudo dnf install -y vicinae; then
        vicinae_bin="$(command -v vicinae 2>/dev/null || true)"
      fi
    fi

    if [[ -z "$vicinae_bin" ]] && command -v curl >/dev/null 2>&1; then
      status_line "ACTION" "Vicinae" "installing via official script (https://vicinae.com/install)"
      if curl -fsSL https://vicinae.com/install | bash; then
        vicinae_bin="$(command -v vicinae 2>/dev/null || true)"
        [[ -z "$vicinae_bin" && -x "/usr/local/bin/vicinae" ]] && vicinae_bin="/usr/local/bin/vicinae"
      fi
    fi

    if [[ -z "$vicinae_bin" ]]; then
      status_line "FAIL" "Vicinae" "install failed; see https://vicinae.com"
      return
    fi
  fi
  status_line "OK" "Vicinae" "$vicinae_bin"

  if command -v systemctl >/dev/null 2>&1; then
    if systemctl --user is-enabled vicinae.service >/dev/null 2>&1 \
       && systemctl --user is-active vicinae.service >/dev/null 2>&1; then
      status_line "OK" "vicinae.service" "enabled & active"
    else
      status_line "ACTION" "vicinae.service" "enabling and starting user service"
      if systemctl --user enable --now vicinae.service >/dev/null 2>&1; then
        status_line "OK" "vicinae.service" "enabled & active"
      else
        status_line "WARN" "vicinae.service" "could not enable automatically; run: systemctl --user enable --now vicinae.service"
      fi
    fi
  fi

  configure_vicinae_gnome_shortcut "$vicinae_bin"
  install_gnome_extension_by_pk "8594" "vicinae" "Vicinae GNOME extension" "https://extensions.gnome.org/extension/8594/vicinae/"
}

ensure_instant_screenshot() {
  remove_gnome_custom_keybinding "flameshot"
  install_gnome_extension_by_pk "9786" "auto-capture@deepan" "GhostShot GNOME extension" "https://extensions.gnome.org/extension/9786/instant-area-screenshot/"

  # Apply GNOME 51 / Mutter 51 compatibility fix (selection box + visible cursor outside panel)
  local ghostshot_patch="$ROOT/gnome/ghostshot-extension.js"
  local ghostshot_dest="$HOME/.local/share/gnome-shell/extensions/auto-capture@deepan/extension.js"
  if [[ -r "$ghostshot_patch" && -d "$(dirname "$ghostshot_dest")" ]]; then
    if ! cmp -s "$ghostshot_patch" "$ghostshot_dest" 2>/dev/null; then
      cp "$ghostshot_patch" "$ghostshot_dest"
      status_line "OK" "GhostShot GNOME 51 patch" "updated $ghostshot_dest"
    fi
  fi

  if command -v gsettings >/dev/null 2>&1 \
     && gsettings list-schemas 2>/dev/null | grep -qx "org.gnome.shell.keybindings"; then
    local desired="['<Shift><Super>s', 'Print']"
    local cur
    cur="$(gsettings get org.gnome.shell.keybindings show-screenshot-ui 2>/dev/null || true)"
    if [[ "$cur" != "$desired" ]]; then
      gsettings set org.gnome.shell.keybindings show-screenshot-ui "$desired" 2>/dev/null || true
    fi
    status_line "OK" "GNOME screenshot shortcut" "Super+Shift+S / Print -> native instant area capture"
  fi
}

ensure_gnome_power_shortcuts() {
  if ! command -v gsettings >/dev/null 2>&1 \
     || ! gsettings list-schemas 2>/dev/null | grep -qx "org.gnome.settings-daemon.plugins.media-keys"; then
    return
  fi

  local desired_suspend="['<Control><Alt>q']"
  local cur_suspend
  cur_suspend="$(gsettings get org.gnome.settings-daemon.plugins.media-keys suspend 2>/dev/null || true)"
  if [[ "$cur_suspend" != "$desired_suspend" ]]; then
    gsettings set org.gnome.settings-daemon.plugins.media-keys suspend "$desired_suspend" 2>/dev/null || true
  fi
  status_line "OK" "GNOME suspend shortcut" "Ctrl+Alt+Q -> suspend"

  local desired_logout="['<Control><Alt>l', '<Control><Alt>Delete']"
  local cur_logout
  cur_logout="$(gsettings get org.gnome.settings-daemon.plugins.media-keys logout 2>/dev/null || true)"
  if [[ "$cur_logout" != "$desired_logout" ]]; then
    gsettings set org.gnome.settings-daemon.plugins.media-keys logout "$desired_logout" 2>/dev/null || true
  fi
  status_line "OK" "GNOME logout shortcut" "Ctrl+Alt+L -> log out"
}

ensure_gnome_audio() {
  # 1. Enable GNOME Over-Amplification (allows volume up to 150%)
  if command -v gsettings >/dev/null 2>&1 \
     && gsettings list-schemas 2>/dev/null | grep -qx "org.gnome.desktop.sound"; then
    local cur_overamp
    cur_overamp="$(gsettings get org.gnome.desktop.sound allow-volume-above-100-percent 2>/dev/null || true)"
    if [[ "$cur_overamp" != "true" ]]; then
      gsettings set org.gnome.desktop.sound allow-volume-above-100-percent true 2>/dev/null || true
    fi
    status_line "OK" "GNOME over-amplification" "enabled (up to 150%)"
  fi

  # 2. Install WirePlumber rule to ignore K66's inaccurate hardware dB curve
  local wp_src="$ROOT/gnome/50-k66-ignore-db.conf"
  local wp_dest="$HOME/.config/wireplumber/wireplumber.conf.d/50-k66-ignore-db.conf"
  if [[ -r "$wp_src" ]]; then
    local changed=false
    if [[ "$(readlink "$wp_dest" 2>/dev/null || true)" != "$wp_src" ]] && ! cmp -s "$wp_src" "$wp_dest" 2>/dev/null; then
      changed=true
    fi
    link_or_copy "$wp_src" "$wp_dest"
    if [[ "$changed" == true ]] && command -v systemctl >/dev/null 2>&1; then
      systemctl --user restart wireplumber pipewire pipewire-pulse >/dev/null 2>&1 || true
      sleep 1
      status_line "OK" "WirePlumber K66 ignore-dB" "restarted PipeWire/WirePlumber"
    fi
  fi

  # 3. Max out K66 hardware ALSA PCM mixer if K66 USB Audio is connected
  if command -v amixer >/dev/null 2>&1 && [[ -d /proc/asound/K66 ]]; then
    amixer -c K66 sset PCM 100% unmute >/dev/null 2>&1 || true
    status_line "OK" "K66 ALSA hardware PCM" "100% (0.00dB)"
  fi
}

setup_module() {
  if [[ "$OS" != "linux" ]]; then
    status_line "SKIP" "GNOME desktop (Vicinae, GhostShot, power shortcuts, audio)" "linux only"
    return
  fi
  ensure_vicinae
  ensure_instant_screenshot
  ensure_gnome_power_shortcuts
  ensure_gnome_audio
}

check_module() {
  if [[ "$OS" != "linux" ]]; then
    status_line "SKIP" "GNOME desktop (Vicinae, GhostShot)" "linux only"
    return
  fi
  check_cmd "wl-copy" "wl-clipboard"
  check_cmd "vicinae" "vicinae (launcher)"
  if command -v systemctl >/dev/null 2>&1; then
    if systemctl --user is-active vicinae.service >/dev/null 2>&1; then
      status_line "OK" "vicinae.service" "active"
    else
      status_line "WARN" "vicinae.service" "not active (run: systemctl --user enable --now vicinae.service)"
    fi
  fi
  if check_gnome_ext_pattern "vicinae"; then
    status_line "OK" "Vicinae GNOME extension" "installed"
  else
    status_line "WARN" "Vicinae GNOME extension" "missing (https://extensions.gnome.org/extension/8594/vicinae/)"
  fi
  if check_gnome_ext_pattern "auto-capture@deepan"; then
    status_line "OK" "GhostShot GNOME extension" "installed"
  else
    status_line "WARN" "GhostShot GNOME extension" "missing (https://extensions.gnome.org/extension/9786/instant-area-screenshot/)"
  fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"
  run_standalone_module "$@"
fi
