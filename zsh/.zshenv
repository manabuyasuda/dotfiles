# mise のシムを非インタラクティブシェル（VS Codeタスク等）でも有効にする
# ネイティブインストール（~/.local/bin）を優先するため shims より後に prepend する
export PATH="$HOME/.local/share/mise/shims:$PATH"
# OrbStack の CLI（docker / docker-compose 等）。初回起動時に ~/.orbstack/bin が作られる
export PATH="$HOME/.orbstack/bin:$PATH"
export PATH="$HOME/.local/bin:$PATH"
