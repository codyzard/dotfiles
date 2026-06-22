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
gckp() { git checkout "$1" && git pull; }
alias gl1='git log --oneline'
alias grb='git rebase '
alias grbm='git rebase master'
alias gpl='git pull'
alias gst='git stash'
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


### ANY
alias stan="vendor/bin/phpstan -vvv analyze -c .phpstan-use-baseline.neon --memory-limit=4G "
alias pf="cd ./php_dev_tools && composer format && cd .."
# ol [role_number]
#   ol      -> auto MFA device 1, choose AWS role manually
#   ol 15   -> auto MFA device 1 and AWS role 15
ol() {
  local item="zw7ajg7cpadfb7don74pup2neu"  # 1Password "OneLogin" (password + OTP)
  local role="$1"
  local pw otp
  pw="$(op item get "$item" --fields label=password --reveal)" || return 1
  otp="$(op item get "$item" --otp)" || return 1
  cd ~/work/onelogin || return 1
  if [[ -n "$role" ]]; then
    # device "1" + role number, then EOF -> exits cleanly
    printf '1\n%s\n' "$role" | onelogin-aws-assume-role --profile default \
      --onelogin-password "$pw" --otp "$otp"
  else
    # device "1" auto, keep tty open so you can type the role
    { echo 1; cat; } | onelogin-aws-assume-role --profile default \
      --onelogin-password "$pw" --otp "$otp"
  fi
}

## ssh
alias stgdeploy="ssh aws-ssm-prtimes-staging-deploy-alma9"
alias proddeploy="ssh aws-ssm-prtimes-production-deploy-alma9"
alias stgweb="ssh aws-ssm-prtimes-staging-php81-web01"
