#!/bin/zsh
[ -f ~/.zshrc.local ] && source ~/.zshrc.local
aws sso login --profile "${AWS_PROFILE:?AWS_PROFILE is not set}"
