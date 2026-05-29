# mise のシムを非インタラクティブシェル（VS Codeタスク等）でも有効にする
# ネイティブインストール（~/.local/bin）を優先するため shims より後に prepend する
export PATH="$HOME/.local/share/mise/shims:$PATH"
export PATH="$HOME/.local/bin:$PATH"
