# Codex config.toml を dotfiles で管理する

## 目的

`~/.codex/config.toml` のモデル・TUI（status line等）を `codex/config.toml` で管理する。

## 制約

- Codexは `[projects.*]` と `[hooks.state.*]` を `config.toml` に書き込む
- symlinkだとtrust状態がdotfilesリポジトリに混入するため、通常ファイル + マージ方式にする

## 実装（完了）

1. `codex/config.toml` — 管理対象の設定のみ
2. `scripts/merge-codex-config.sh` — dotfiles設定を反映し、ローカルruntimeセクションを保持
3. `setup.sh` — mergeを実行（symlink一覧には載せない）
4. README.mdに運用を集約

## 運用

- status lineの変更: `codex/config.toml` を編集 → `./setup.sh`
- TUIの `/statusline` で変更した場合: ローカルにのみ反映。dotfilesへ取り込むときは手動コピー
- モデル変更: `codex/config.toml` の `model` を編集してmerge
