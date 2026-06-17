### PNPM
alias p="pnpm "
alias pi="pnpm install"
alias pd="pnpm dev"
alias pb="pnpm build"
alias ps="pnpm start"
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
alias gckp='git checkout $1 && git pull'
alias gl1='git log --oneline'
alias grb='git rebase '
alias grbm='git rebase main'
alias gpl='git pull'
alias gst='git stash'
alias gstp='git stash pop'
alias gpo='git push origin '
alias grs1='git reset --soft HEAD~1'
alias gplr='gaa && gst && gck main && gpl && gstp' # stash & pull origin main & stash pop

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


### ANY
alias stan="vendor/bin/phpstan -vvv analyze -c .phpstan-use-baseline.neon --memory-limit=4G "
alias pf="cd ./php_dev_tools && composer format && cd .."
ol() {
  local item="zw7ajg7cpadfb7don74pup2neu"  # 1Password "OneLogin" (password + OTP)
  local pw otp
  pw="$(op item get "$item" --fields label=password --reveal)" || return 1
  otp="$(op item get "$item" --otp)" || return 1
  cd ~/work/onelogin || return 1
  # feed MFA device "1", then hand tty back for the role prompt
  { echo 1; cat; } | onelogin-aws-assume-role --profile default \
    --onelogin-password "$pw" --otp "$otp"
}
