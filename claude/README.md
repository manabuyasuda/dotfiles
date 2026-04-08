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
  rules/              ファイルパターン別ルール（paths: 指定で必要な時だけ適用）
  hooks/              hooks スクリプト
```

---

## スキル一覧

### ローカルスキル（`claude/skills/` で管理）

`/スキル名` または自然言語で呼び出す。

| スキル | 呼び出し例 | 概要 |
|---|---|---|
| `code-review` | 「PRレビューして」「#123をレビュー」 | GitHub PR またはローカルブランチの変更をレビュー |
| `hotspot-refactoring` | 「hotspot」「リファクタリング提案して」 | git log の hotspot 分析・循環参照・不安定性メトリクスからリファクタリング優先候補を提案 |
| `pr-dashboard` | 「自分のPR確認して」「通知確認して」 | PR・レビュー依頼・GitHub 通知を gh コマンドで確認するアシスタント |
| `rebasing-feature-branch` | 「リベースして」「mainを取り込んで」 | フィーチャーブランチをベースブランチにリベースするワークフロー |
| `retrospective` | 「ふりかえりして」 | セッションの KPTA ふりかえりを実施し `retrospective/YYYY-MM-DD.md` に記録 |

### 3rd party スキル

プロジェクトのリポジトリ側でインストールして使う。dotfilesでは管理しない。

```bash
# プロジェクトルートで実行
npx skills add vercel-labs/agent-skills
```

ソース: [vercel-labs/agent-skills](https://github.com/vercel-labs/agent-skills)（vercel-composition-patterns / vercel-react-best-practices / web-design-guidelines）

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

### showThinkingSummaries

```json
{ "showThinkingSummaries": true }
```

回答前の思考要約を表示する。「調査が不十分なまま編集に入っている」と感じたときに、どのファイルを読んだか・読んでいないかを確認できる。思考が浅いと判断したらタスクを中断して `/effort high` をかけ直す。

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
| `Read/Edit/Write(.env*)` | `.env` ファイルの読み取り・編集（シークレット漏洩防止） |
| `gh repo delete*` | リポジトリ削除 |
| `gh secret set/delete/remove*` | シークレット書き込み・削除（`gh secret list` は許可） |
| `gh api --method DELETE*` / `gh api -X DELETE*` | GitHub API 経由の DELETE |
| `gh pr merge*` | PR マージ |
| `npm/pnpm/yarn publish*` | パッケージ公開 |

---

## Rules（ファイルパターン別ルール）

`claude/rules/` に置いたMarkdownファイルは、`paths:` frontmatterで指定したファイルパターンに一致する作業をするときだけ自動適用される。CLAUDE.mdに書くと常に読み込まれる内容を、関係するファイルを編集するときだけ有効にできる。

```markdown
---
paths:
  - "**/*.md"
---

ここに **/*.md ファイルを編集するときだけ適用したいルールを書く。
```

### 現在のルール一覧

| ファイル | 対象 | 内容 |
|---|---|---|
| `rules/markdown.md` | `**/*.md` | Markdown 文書の記述ルール（見出し・強調・情報源の明記など） |

### ルールを追加するとき

CLAUDE.mdに書いていた指示のうち「特定のファイル種別を編集するときだけ必要」なものを `rules/` に移すとCLAUDE.mdの注意コストを下げられる。

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
| `git commit`（作業記録ファイル・ディレクトリがステージ済み） | **deny**（`WORK_RECORD_FILES` / `WORK_RECORD_DIRS` に一致するファイルはコミット禁止） |
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

保護ブランチと作業記録ファイルの定義を一元管理する。`pre-tool-use/branch-guard.sh` と `pre-tool-use/bash-guard.sh` が `source` して使用する。

| 変数 | 内容 |
|---|---|
| `PROTECTED_BRANCHES` | 直接編集・ローカルマージを禁止するブランチ（デフォルト: `main`, `release/*`, `production` 等） |
| `WORK_RECORD_FILES` | コミット禁止の作業記録ファイル（`explore.md`, `plan.md`, `retrospective.md`） |
| `WORK_RECORD_DIRS` | コミット禁止の作業記録ディレクトリ（配下のファイルすべて禁止: `explore/`, `plan/`, `retrospective/`） |

---

## 設定の改善タイミング

セッション中に気づいた改善点は `retrospective/YYYY-MM-DD.md` にK/Pとして記録する。
振り返るときは `/retrospective` を呼ぶ。

### トリガーと対応ファイル

#### 同じ deny / ask が複数回発生する
`hooks/pre-tool-use/` にルールを追加する。

| 例 | 対応 |
|---|---|
| 特定コマンドを無断実行する | `dangerous-guard.sh` / `bash-guard.sh` にパターン追加 |
| 保護すべきファイルを直接編集する | `file-protect.sh` に対象パターン追加 |
| 特定ブランチで直接作業する | `config.sh` の `PROTECTED_BRANCHES` に追加 |

#### 同じ permission を何度も承認している
`settings.json` のallowに昇格させる。  
逆に「毎回askが出るが毎回許可している」場合も同様。

#### よく使うワークフローが定型化してきた

Q1: 毎回同じ手順で実行できるか？  
→ YES: `skills/` に切り出す（`/スキル名` で呼び出す）  
→ NO（状況で判断が変わる）: `agents/` に切り出す（`@エージェント名` で呼び出す）

Q2: ユーザーが明示的に呼び出すか、自律的に動かすか？  
→ 明示的: `skills/`  
→ 自律的（サブタスク委譲）: `agents/`

#### 特定の指示・判断基準を毎回伝えている

| 条件 | 対応 |
|---|---|
| すべての会話に共通する制約（短く書ける） | `CLAUDE.md` に追記 |
| 手順が定まっていてスキルとして呼び出したい | `skills/` に切り出す |
| 自律的に判断させたいタスク | `agents/` に切り出す |

`CLAUDE.md` は最小限に保つ（目安100行以内）。詳細は `skills/` / `agents/` に分離し、呼び出されたときだけ読み込まれる設計を維持する。

#### 新しいツール・サービスを導入した
`settings.json` のallow/denyにコマンドを追加し、`hooks/session-start/session-start.sh` に検出ロジックを追加する。

#### フィードバックが遅い・チェックが CI のみになっている
`hooks/post-tool-use/` に移す。編集後すぐに走るほど速いフィードバックが得られる。

#### キーバインドを変えたい
`keybindings.json` を編集する（`/keybindings-help` スキルを使う）。

---

### ファイル別の更新タイミング

| ファイル | 更新するとき |
|---|---|
| `CLAUDE.md` | 行動原則・作業フローが変わったとき（目安100行以内） |
| `rules/` | 特定ファイル種別の編集時だけ適用するルールを追加・変更するとき |
| `memory/` | セッション横断で記憶すべき好みや知見が生まれたとき |
| `settings.json` | allow/deny の追加・hook の登録変更・モデル変更 |
| `settings.json#env` | Claude Code の環境変数を調整するとき |
| `settings.json#enabledPlugins` | プラグインの有効/無効を変えるとき |
| `keybindings.json` | キーバインドを変更・追加するとき |
| `hooks/pre-tool-use/` | 「このミスを二度とさせない」とき |
| `hooks/post-tool-use/` | 「編集後に自動で走らせたいチェック」が増えたとき |
| `hooks/session-start/` | 検出すべきツールやコンテキストが変わったとき |
| `hooks/config.sh` | 保護ブランチ・作業記録ファイルの構成が変わったとき |
| `skills/` | 定型ワークフローを切り出すとき |
| `agents/` | 自律的な調査・検証タスクを切り出すとき |
| `README.md` | 上記のいずれかを変更したとき（実態と乖離させない） |
