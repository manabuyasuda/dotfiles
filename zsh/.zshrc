# mise（言語ランタイム + Node系ツール管理）
eval "$(mise activate zsh)"
eval "$(direnv hook zsh)"

# ネイティブインストール（~/.local/bin の claude 等）を mise shims より優先する
# mise activate の後に prepend することで .local/bin を PATH 先頭に置く
export PATH="$HOME/.local/bin:$PATH"

# Claude Codeの環境変数をクリア（新しいターミナルでclaudeコマンドを直接実行可能にする）
unset CLAUDECODE 2>/dev/null

# Socket Firewall でパッケージマネージャーをラップする
alias npm="sfw npm"
alias npx="sfw npx"
alias yarn="sfw yarn"
alias pnpm="sfw pnpm"
alias pip="sfw pip"
alias uv="sfw uv"
alias cargo="sfw cargo"

# local overrides (not tracked in dotfiles)
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local
