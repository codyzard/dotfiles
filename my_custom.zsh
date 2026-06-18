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
# ol -> fetch password + OTP from 1Password, auto-pick MFA device 1,
#       then pick the AWS role manually. cwd restored after login.
ol() {
  local item="zw7ajg7cpadfb7don74pup2neu"  # 1Password "OneLogin" (password + OTP)
  local pw otp
  pw="$(op item get "$item" --fields label=password --reveal)" || return 1
  otp="$(op item get "$item" --otp)" || return 1
  ( cd ~/work/onelogin || exit 1
    PW="$pw" OTP="$otp" expect -c '
      set timeout 60
      spawn onelogin-aws-assume-role --profile default --onelogin-password $env(PW) --otp $env(OTP)
      expect { "MFA Device" { send "1\r" } timeout {} }
      interact
    '
  )
}

## ssh
alias stgdeploy="ssh aws-ssm-prtimes-staging-deploy-alma9"
alias proddeploy="ssh aws-ssm-prtimes-production-deploy-alma9"
alias stgweb="ssh aws-ssm-prtimes-staging-php81-web01"
