### PNPM
alias p="pnpm "
alias pi="pnpm install"
alias pd="pnpm dev"
alias pb="pnpm build"
alias pst="pnpm start" # Avoid shadowing system /bin/ps
alias pt="pnpm test"
alias ptu="pnpm test -- -u"
alias ptuw="pnpm test:watch -- -u"

### Git
alias gck="git checkout "
alias gs="git status"
alias ga="git add "
alias gaa="git add ."
alias gc="git commit "
alias gac="git add . && git commit "
alias gb="git branch"
gckp() { git checkout "$1" && git pull; }
alias gl1='git log --oneline'
alias grb='git rebase '
alias grbm='git rebase master'
alias gpl='git pull'
alias gst='gaa && git stash'
alias gstp='git stash pop'
alias gpo='git push origin '
alias grs1='git reset --soft HEAD~1'
# gplr [branch]  -> stash, pull <branch> (default master), restore
#   gplr          # master
#   gplr main
#   gplr develop
gplr() {
  local branch="${1:-master}"
  git add .
  if git stash | grep -q 'Saved'; then local popped=1; fi
  git checkout "$branch" && git pull
  [[ -n "$popped" ]] && git stash pop
}

### Docker
alias d="docker"
alias dc="docker compose "
alias dcb="docker compose build "
alias dcu="docker compose up "
alias dce="docker compose exec "

### AI CLI
alias cc=claude
alias cx=codex
alias cg=gemini
alias kr=kiro-cli
alias oc=opencode
alias h=herdr # running agent

### Helpers
checkcmd() {
  local custom_dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
  cat "$custom_dir/my_custom.zsh"
  if [[ -r "$custom_dir/work.zsh" ]]; then
    echo ""
    echo "### Work (local: $custom_dir/work.zsh)"
    cat "$custom_dir/work.zsh"
  fi
}
