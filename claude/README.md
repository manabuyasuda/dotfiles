# Claude Code設定リファレンス

このディレクトリ（`claude/`）はClaude Codeのグローバル設定を管理する。
`setup.sh` によって `~/.claude/` 以下にシンボリックリンクが張られる。

---

## ディレクトリ構成

```
claude/
  CLAUDE.md           グローバル指示（日本語応答・ツール活用方針・作業フロー）
  settings.json       権限設定・モデル・hooks の登録
  README.md           このファイル
  skills/             スキル定義（/skill-name で呼び出す）
  agents/             サブエージェント定義
  hooks/              hooks スクリプト
```

---

## スキル一覧

`/スキル名` または自然言語で呼び出す。

| スキル | 呼び出し例 | 概要 |
|---|---|---|
| `code-review` | 「PRレビューして」「#123をレビュー」 | GitHub PR またはローカルブランチの変更をレビュー |
| `hotspot-refactoring` | 「hotspot」「リファクタリング提案して」 | git log の hotspot 分析・循環参照・不安定性メトリクスからリファクタリング優先候補を提案 |
| `pr-dashboard` | 「自分のPR確認して」「通知確認して」 | PR・レビュー依頼・GitHub 通知を gh コマンドで確認するアシスタント |
| `rebasing-feature-branch` | 「リベースして」「mainを取り込んで」 | フィーチャーブランチをベースブランチにリベースするワークフロー |
| `retrospective` | 「ふりかえりして」 | セッションの KPTA ふりかえりを実施し `Retrospective.md` に記録 |
| `vercel-composition-patterns` | 「コンポーネント設計を見て」 | React のコンポジションパターン（boolean prop 削減・Compound Components など） |
| `vercel-react-best-practices` | 「パフォーマンスレビューして」 | Vercel Engineering の React / Next.js パフォーマンス最適化ガイドライン |
| `vercel-react-native-skills` | 「React Native のコードを見て」 | React Native / Expo のパフォーマンス・アニメーション・リスト最適化 |
| `web-design-guidelines` | 「UIをレビューして」「アクセシビリティ確認して」 | Web Interface Guidelines に基づく UI・アクセシビリティ・UX のレビュー |

---

## エージェント一覧

`@エージェント名` で呼び出す。Claude Codeがサブエージェントとして自律的に呼び出す場合もある。

| エージェント | 呼び出し例 | 概要 |
|---|---|---|
| `digg` | `@digg` | 技術ドキュメントや調査結果を批判的にレビューし、「実装に着手できる状態か」を検証する。問題を直すのではなく、不足している観点を質問リストとして返す |

---

## 基本設定（settings.json）

### モデル

`claude-sonnet-4-6`

### 権限（permissions）

**自動許可（allow）**: 読み取り専用・安全な操作は確認なしで実行する。

| カテゴリ | コマンド例 |
|---|---|
| GitHub PR | `gh pr list/view/diff/checks/status/checkout/comment/review` |
| GitHub Repo / Issue / Run | `gh repo view/list`, `gh issue list/view`, `gh run list/view` |
| GitHub API（読み取り） | `gh api repos*`, `gh api notifications*`, `gh api graphql*`, `gh api user*` |
| GitHub CLI 拡張 | `gh dash`, `gh f`, `gh s`, `gh notify`, `gh search` |
| Git 読み取り | `git log`, `git status`, `git diff`, `git show`, `git remote`, `git stash list`, `git branch --show-current` |
| 依存関係・コード解析 | `madge`, `knip`, `depcruise`, `semgrep`, `type-coverage` |
| ファイル検索 | `fd`, `tree` |
| HTML・アクセシビリティ | `html-validate`, `axe` |
| CSS 解析 | `wallace`, `colorguard` |
| バンドル・パッケージ | `bundle-phobia`, `ncu`（npm-check-updates） |
| デプロイ・CI | `firebase list/functions:list/hosting:channel:list`, `vercel ls/list/inspect/logs/whoami/projects`, `lhci collect/assert/open/healthcheck` |
| API ドキュメント | `redocly lint/stats/bundle/split/check-config/build-docs` |

**拒否（deny）**: 以下は常にブロック。

| コマンド | 理由 |
|---|---|
| `gh repo delete*` | リポジトリ削除 |
| `gh secret set/delete/remove*` | シークレット書き込み・削除（`gh secret list` は許可） |
| `gh api --method DELETE*` / `gh api -X DELETE*` | GitHub API 経由の DELETE |
| `gh pr merge*` | PR マージ |
| `npm/pnpm/yarn publish*` | パッケージ公開 |

---

## Hooks

### 実行タイミング一覧

```
セッション開始
  └─ SessionStart ──────────── session-start/session-start.sh

ファイル編集前（Edit / MultiEdit / Write）
  ├─ PreToolUse ──────────── pre-tool-use/branch-guard.sh
  ├─ PreToolUse ──────────── pre-tool-use/file-protect.sh
  └─ PreToolUse ──────────── pre-tool-use/mermaid-guard.sh

Bash 実行前
  ├─ PreToolUse ──────────── pre-tool-use/bash-guard.sh
  └─ PreToolUse ──────────── pre-tool-use/dangerous-guard.sh

ファイル編集後（Edit / MultiEdit / Write）
  ├─ PostToolUse ─────────── post-tool-use/format.sh
  ├─ PostToolUse ─────────── post-tool-use/install.sh
  ├─ PostToolUse ─────────── post-tool-use/test.sh
  ├─ PostToolUse ─────────── post-tool-use/typecheck.sh
  └─ PostToolUse ─────────── post-tool-use/mermaid-guard.sh

Claude の応答完了時
  └─ Stop ─────────────────── notification/notify.sh

通知イベント（permission_prompt / idle_prompt / elicitation_dialog）
  └─ Notification ─────────── notification/notify.sh

Worktree 操作
  ├─ WorktreeCreate ────────── worktree/create.sh
  └─ WorktreeRemove ────────── worktree/remove.sh
```

### 各 hook の詳細

#### `session-start/session-start.sh` — SessionStart

セッション開始時に1回だけ実行。エージェントに作業環境のコンテキストを提供する。

- Node.jsバージョン・パッケージマネージャーの検出
- フォーマッター（biome / prettier）・リンター（biome / eslint）の検出
- テストランナー（vitest / jest）・テストユーティリティの検出
- TypeScript・モノレポ構成の検出
- `$CLAUDE_ENV_FILE` に環境変数を書き出し（後続のpost-tool-useフックが参照）
- 現在ブランチ・直近コミット・未コミット変更を表示

---

#### `pre-tool-use/branch-guard.sh` — PreToolUse（Edit / MultiEdit / Write）

保護ブランチ上でのファイル直接編集を **deny（ハードブロック）**。  
`config.sh` で定義したブランチパターン（`main`, `develop`, `release/*` 等）に一致する場合、フィーチャーブランチの作成を促す。

---

#### `pre-tool-use/file-protect.sh` — PreToolUse（Edit / MultiEdit / Write）

機密ファイル・lock filesへの直接書き込みを **deny**。

| 保護対象 | 例 |
|---|---|
| 環境変数・認証情報 | `.env`, `.npmrc`, `.netrc` |
| 秘密鍵・証明書 | `.pem`, `.key`, `.p12` |
| Git 内部ファイル | `.git/` 以下 |
| lock files（JS） | `package-lock.json`, `yarn.lock`, `pnpm-lock.yaml` |
| lock files（Python / Ruby / Go / Rust） | `poetry.lock`, `Gemfile.lock`, `go.sum`, `Cargo.lock` |
| Terraform 状態 | `.tfstate`, `.tfvars` |

---

#### `pre-tool-use/mermaid-guard.sh` — PreToolUse（Edit / MultiEdit / Write）

`.md` ファイルへの書き込み前にMermaidラベル内の `\n` リテラルを検出してブロック。  
（Mermaidの構文エラーを事前に防ぐ）

---

#### `pre-tool-use/bash-guard.sh` — PreToolUse（Bash）

Bashコマンド実行前の安全確認。以下をチェックする。

| チェック | 動作 |
|---|---|
| `description` 未入力 | **deny**（意図不明なコマンドは実行しない） |
| バックスラッシュ改行（継続行） | **deny**（allow パターンの glob が改行にマッチしないため） |
| `rm` 単体 / `unlink` / `truncate` | **ask**（単体削除は確認） |
| `git push --force-with-lease` | **ask**（リベース後の push として確認） |
| `git push --force` / `-f` | **ask**（リモート履歴の上書きとして確認） |
| `git push`（通常） | **ask**（リモート公開として確認） |
| `git commit --amend` | **ask**（公開済みコミット書き換えリスクを確認） |
| `git commit`（Explore/Plan/Retrospective.md がステージ済み） | **deny**（作業記録ファイルはコミット禁止） |
| `git commit`（通常） | **ask** |
| `git merge`（保護ブランチ上） | **deny**（PR 経由を強制） |
| `git reset --hard` | **ask**（未コミット変更消失を確認） |

---

#### `pre-tool-use/dangerous-guard.sh` — PreToolUse（Bash）

不可逆な破壊的コマンドを **deny**。deny時はコマンドを明示し、必要なら手動実行を促す。

| コマンド | 理由 |
|---|---|
| `rm -rf` / `rm -r` | 再帰削除。git 管理外も復元不可 |
| `shred` | 上書き削除。git 管理下でも復元不可 |
| `xargs rm/unlink/shred` | xargs 経由の大量削除 |
| `find -delete` / `find -exec rm` | find 経由の大量削除 |
| `DROP TABLE` / `DROP DATABASE` | DB データ消失 |
| `curl\|sh` / `wget\|bash` | リモートコード実行 |

---

#### `post-tool-use/format.sh` — PostToolUse（Edit / MultiEdit / Write）

ファイル編集後に自動フォーマットを実行する。

- `*.js / *.jsx / *.ts / *.tsx` → biomeまたはprettier
- `*.md` → textlint（textlintがある場合のみ）

---

#### `post-tool-use/install.sh` — PostToolUse（Edit / MultiEdit / Write）

`package.json` を直接編集したとき、lock fileとの整合性を保つために自動で `install` を実行する。

---

#### `post-tool-use/test.sh` — PostToolUse（Edit / MultiEdit / Write）

`*.test.js / *.test.ts` 等のテストファイルを編集したとき、関連テストのみを自動実行する。  
（vitestまたはjest）

---

#### `post-tool-use/typecheck.sh` — PostToolUse（Edit / MultiEdit / Write）

`*.ts / *.tsx` を編集したとき、`tsc --noEmit` で型チェックを実行する。  
型エラーがあってもexit 0（非ブロッキング）。エラー内容はfeedbackとしてClaudeに渡す。

---

#### `post-tool-use/mermaid-guard.sh` — PostToolUse（Edit / MultiEdit / Write）

`.md` ファイル編集後に `mmdc` でMermaidブロックを検証する。エラーがあればClaudeに通知。

---

#### `notification/notify.sh` — Notification / Stop

| イベント | 条件 | 通知内容 |
|---|---|---|
| `Notification` | `permission_prompt` | Claude の `message` フィールドをそのまま表示 |
| `Notification` | `idle_prompt` | 同上 |
| `Notification` | `elicitation_dialog` | 同上（MCP サーバーからの質問文） |
| `Stop` | — | Claudeの応答テキスト（`message` フィールド）をそのまま表示 |

通知音: Glass（terminal-notifier）

---

#### `worktree/create.sh` / `worktree/remove.sh` — WorktreeCreate / WorktreeRemove

`wtp` ツールを使ったgit worktreeの作成・削除ワークフロー。  
作成時: gitignore対象ファイルのコピー・初期化コマンドのクリップボードコピー・VS Code / SourceTreeを開く  
削除時: `gh poi --state closed` をクリップボードにコピー

---

## 共有設定

#### `hooks/config.sh`

保護ブランチの定義を一元管理する（デフォルト: `main`, `release/*`, `production`等）。`pre-tool-use/branch-guard.sh` と `pre-tool-use/bash-guard.sh` が `source` して使用する。

---

## 設定の改善タイミング

ハーネスエンジニアリングの原則「エージェントのミスごとにフィードバックを強化する」に基づき、以下のトリガーで改善を検討する。

### トリガーと改善対象ファイルの対応

#### エージェントが同じミスを繰り返す
`hooks/pre-tool-use/` にdeny/askルールを追加する。

| 例 | 対応 |
|---|---|
| 特定コマンドを無断実行する | `dangerous-guard.sh` / `bash-guard.sh` にパターン追加 |
| 保護すべきファイルを直接編集する | `file-protect.sh` に対象パターン追加 |
| 特定ブランチで直接作業する | `config.sh` の PROTECTED_BRANCHES に追加 |

#### よく使うワークフローが定型化してきた

| 条件 | 対応 |
|---|---|
| 手順が決まっていて毎回同じ操作をしている | `skills/` に切り出す（`/スキル名` で呼び出す） |
| 調査内容・判断が状況によって変わる | `agents/` に切り出す（`@エージェント名` で呼び出す） |

#### 特定のレビュー観点・判断基準を毎回伝えている

| 条件 | 対応 |
|---|---|
| すべての会話に共通する制約・原則（短く書ける） | `CLAUDE.md` に追記 |
| 手順が定まっていて `/スキル名` で呼び出したい | `skills/` に切り出す |
| 調査・検証など自律的に判断させたいタスク | `agents/` に切り出す |

`CLAUDE.md` は50行以下を維持する。
詳細情報はskills/agentsに分離し、ユーザーが `/スキル名` または `@エージェント名` で明示的に呼び出したときだけ読み込まれる設計を保つ。

#### 新しいツール・サービスを導入した
`settings.json` のallow/deny + `hooks/session-start/session-start.sh` のツール検出する。

#### フィードバックが遅い・チェックがCIのみになっている
`hooks/post-tool-use/` に移す。

コード編集後に走る静的解析・リンターはPostToolUseフックに置くほど速いフィードバックが得られる。

#### hookがうるさい・ノイズが多い
該当hookの条件を絞る。

「毎回askが出るが毎回許可している」ならそのルールを緩和するかallowに昇格させる。

---

### ファイル別の更新タイミング

| ファイル | 更新するとき |
|---|---|
| `CLAUDE.md` | 行動原則・作業フローが変わったとき（50行以下を維持） |
| `settings.json` | allow/denyの追加・hookの登録変更 |
| `hooks/pre-tool-use/` | 「このミスを二度とさせない」とき |
| `hooks/post-tool-use/` | 「編集後に自動で走らせたいチェック」が増えたとき |
| `hooks/session-start/` | 検出すべきツールやコンテキストが変わったとき |
| `hooks/config.sh` | 保護ブランチの構成が変わったとき |
| `skills/` | 定型ワークフローを切り出すとき |
| `agents/` | 特定の調査・検証タスクを自律化するとき |
| `README.md` | 上記のいずれかを変更したとき（実態と乖離させない） |
