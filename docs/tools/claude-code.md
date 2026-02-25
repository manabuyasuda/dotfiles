# Claude Code

Anthropic製のAIコーディングアシスタントCLI。ターミナルから直接Claudeと対話しながらコードの編集・実行・デバッグ・Git操作を行える。

## インストール

```bash
npm install -g @anthropic-ai/claude-code
```

`nodenv/default-packages`で自動インストールされる。

## 基本的な使い方

```bash
# 対話モードで起動
claude

# 隔離された git worktree 上で起動（WorktreeCreate フックが呼ばれる）
claude --worktree <branch-name>
claude -w <branch-name>

# 1回限りのプロンプトを実行して終了
claude -p "このコードをレビューして"

# 特定のディレクトリで起動
claude /path/to/project
```

## 主要オプション

| オプション | 説明 |
|---|---|
| `--worktree <branch>`, `-w` | 新しい git worktree を作成して Claude を起動する |
| `--print`, `-p` | 1回限りのプロンプトを実行して終了する（非対話モード） |
| `--model <model>` | 使用するモデルを指定する |
| `--no-auto-updater` | 自動更新を無効にする |
| `--version` | バージョンを表示する |

## 設定ファイル

| パス | 説明 |
|---|---|
| `~/.claude/settings.json` | グローバル設定（モデル・hooks・plugins） |
| `~/.claude/CLAUDE.md` | グローバル指示（全プロジェクト共通の指示） |
| `.claude/settings.json` | プロジェクト固有の設定 |
| `CLAUDE.md` | プロジェクト固有の指示 |

## Hooks

Claude Codeのイベントに応じてシェルコマンドを実行できる仕組み。`settings.json`に設定する。

| イベント | 説明 |
|---|---|
| `WorktreeCreate` | `--worktree` でワークツリーを作成するときに呼ばれる。stdout に返したパスに Claude が切り替わる |
| `WorktreeRemove` | `--worktree` セッション終了時に "remove" を選択したときに呼ばれる |
| `PreToolUse` | ツール実行前に呼ばれる。ブロックすることも可能 |
| `Notification` | 通知イベント（`permission_prompt` / `idle_prompt` / `stop`）が発生したときに呼ばれる |

このリポジトリのhooksは`~/.claude/hooks/`に配置されている。

## スラッシュコマンド（対話中）

| コマンド | 説明 |
|---|---|
| `/help` | ヘルプを表示する |
| `/clear` | 会話履歴をクリアする |
| `/compact` | 会話を要約してコンテキストを節約する |
| `/cost` | 現在のセッションのトークン使用量と費用を表示する |

## 参考リンク

- [Claude Code 公式ドキュメント](https://docs.anthropic.com/ja/docs/claude-code/overview)
- [npm - @anthropic-ai/claude-code](https://www.npmjs.com/package/@anthropic-ai/claude-code)
