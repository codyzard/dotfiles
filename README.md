# Dotfiles

Personal dotfiles collected from the current machine. Files are now at repo root, mirroring their `$HOME` paths.

## Contents (flat layout)
- `.zshrc`
- `my_custom.zsh` (links to `~/.oh-my-zsh/custom/my_custom.zsh`)
- `aerospace.toml` (links to `~/.config/aerospace/aerospace.toml`)
- `.wezterm.lua`
- `.vscode/settings.json` (links to VS Code user settings: macOS `~/Library/Application Support/Code/User/settings.json`, Linux `~/.config/Code/User/settings.json`)
- `.gitconfig` (sets git user.name/user.email)

## Usage
1. Back up any existing config files on the target machine.
2. Clone this repo (e.g., `git clone https://... dotfiles`).
3. (Optional) Run environment checks (macOS or Linux):
   ```
   ./setup.sh --check
   ```
   This reports missing tools/paths (oh-my-zsh, plugins, fonts, WezTerm background, etc.).
4. Run the setup script from repo root:
   ```
   ./setup.sh          # symlink mode (default)
   ./setup.sh --copy   # copy files instead of linking
   ```
   Existing files are backed up with a timestamped `.bak.*` suffix.
   If Fira Code is missing, the script auto-installs via Homebrew (macOS) or apt-get (Linux) when available.

Adjust paths as needed if your environment differs.
