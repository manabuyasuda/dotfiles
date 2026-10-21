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

# Codex を gpt-6.1-sol / reasoning high で起動する。
# codex/config.toml に model を書かない理由は同ファイルのコメントを参照。
# 起動時の -m / -c は ~/.codex/config.toml より優先されるため、/model で切り替えて保存されても次の起動で戻る。
codex() {
  command codex -m gpt-6.1-sol -c 'model_reasoning_effort="high"' "$@"
}

# ~/.zshrc.local（dotfiles 管理外）には、公開できない値（アカウントID・会社固有の設定）と
# そのマシンだけで使う設定を置く。dotfiles は公開リポジトリのため、ここには書けない。
# Claude Code の環境変数は zsh を経由しない起動（IDE 等）にも効くよう claude/settings.json の env に置く。
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local
