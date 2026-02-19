export PATH="$HOME/.anyenv/bin:$PATH"
eval "$(anyenv init -)"
eval "$(direnv hook zsh)"
export PATH="$HOME/.local/bin:$PATH"

# Claude Codeの環境変数をクリア（新しいターミナルでclaudeコマンドを直接実行可能にする）
unset CLAUDECODE 2>/dev/null
