# Dotfiles

Personal dotfiles supporting both **macOS** and **Linux** (Fedora `dnf` and Debian/Ubuntu `apt-get`). Each app owns its own colocated `setup.sh`, orchestrated by the root [setup.sh](setup.sh). OS-specific modules are automatically skipped on unsupported platforms.

## Structure & Modules

| Module | Config / Files | Destination | Platforms |
|---|---|---|---|
| `git/` | `git/.gitconfig`, `git/setup.sh` | `~/.gitconfig` | macOS, Linux |
| `zsh/` | `zsh/.zshrc`, `zsh/my_custom.zsh`, `zsh/work.zsh` *(gitignored)*, `zsh/setup.sh` | `~/.zshrc`, `~/.oh-my-zsh/custom/*` | macOS, Linux |
| `ghostty/` | `ghostty/config`, `ghostty/setup.sh` | `~/.config/ghostty/config` | macOS, Linux |
| `herdr/` | `herdr/config.toml`, `herdr/setup.sh` | `~/.config/herdr/config.toml` | macOS, Linux |
| `wezterm/` | `wezterm/.wezterm.lua`, `wezterm/setup.sh` | `~/.wezterm.lua` | macOS, Linux |
| `aerospace/` | `aerospace/aerospace.toml`, `aerospace/setup.sh` | `~/.config/aerospace/aerospace.toml` | macOS only |
| `browser/` | `browser/tabgroups_rules.json`, `browser/firefox/user.js`, `browser/setup.sh` | `~/.config/tabgroups_rules.json`, Firefox profiles | macOS, Linux |
| `gnome/` | `gnome/ghostshot-extension.js`, `gnome/setup.sh` | GNOME Wayland (Vicinae, GhostShot, power shortcuts) | Linux only |
| `.vscode/` | `.vscode/settings.json`, `.vscode/setup.sh` | macOS: `~/Library/Application Support/Code/User/settings.json`<br>Linux: `~/.config/Code/User/settings.json` | macOS, Linux |
| `lib/` | `lib/common.sh` | Shared helpers (`pkg_install`, `link_or_copy`, `check_*`, etc.) | macOS, Linux |

## Usage

1. Clone this repo:
   ```bash
   git clone https://github.com/codyzard/dotfiles.git ~/work/dotfiles
   cd ~/work/dotfiles
   ```
2. (Optional) Create local work-specific aliases/functions (gitignored):
   ```bash
   cp zsh/work.zsh.example zsh/work.zsh
   ```
3. Run checks or setup (full or per-module):
   ```bash
   ./setup.sh                      # run all modules (symlink mode, idempotent)
   ./setup.sh --check              # check environment without modifying anything
   ./setup.sh --copy               # copy files instead of symlinking
   ./setup.sh --install-missing    # also install/guide optional CLIs (ghostty, claude, codex, gemini, lms)
   ./setup.sh --only zsh           # run a single module (repeatable: --only zsh --only gnome)
   ./setup.sh --list               # list available modules
   ./gnome/setup.sh --check        # run any colocated module standalone
   ```
   - Automatically installs `zsh`, Oh My Zsh, and Zsh autocomplete/highlighting plugins (`zsh-autosuggestions`, `zsh-completions`, `zsh-syntax-highlighting`), then sets `zsh` as your default login shell (`chsh -s`).
   - Existing files are backed up with a timestamped `.bak.*` suffix.
   - Missing **Fira Code** font is auto-installed via Homebrew (macOS), `dnf` (Fedora), or `apt-get` (Debian/Ubuntu).

## Linux (Fedora / GNOME Wayland) — `gnome/setup.sh`

Automatically handles on Linux (skipped on macOS):
1. **Vicinae Launcher & Clipboard**:
   - Installs `wl-clipboard` and **Vicinae** (Fedora Copr `scottames/vicinae` or fallback `https://vicinae.com/install`).
   - Enables `systemctl --user enable --now vicinae.service`.
   - Disables GNOME's default `Alt + Space` Window Menu and binds **`Alt + Space`** to `vicinae toggle`.
   - Installs & enables the **Vicinae GNOME Extension** (ID `8594`, required for Clipboard History & Auto-paste on Wayland).
2. **Instant Area Screenshot (GhostShot)**:
   - Installs & enables the **GhostShot** GNOME extension (ID `9786`, `auto-capture@deepan`) with the GNOME 51 / Mutter 51 compatibility patch (`gnome/ghostshot-extension.js`).
   - Binds **`Super + Shift + S`** (and `Print`) to GNOME's native screenshot UI — drag freely across any monitor and release to capture & copy straight to clipboard.
3. **Power Shortcuts**:
   - `Ctrl + Alt + Q` → Suspend, `Ctrl + Alt + L` → Log out.

> After first-time GNOME extension installation on Wayland, **log out and log back in**, then run `systemctl --user restart vicinae.service`.
