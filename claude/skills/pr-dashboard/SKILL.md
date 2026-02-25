---
name: pr-dashboard
description: >
  PR・レビュー・GitHub通知の確認をghコマンドで答えるアシスタント。
  「自分のPR確認して」「レビュー依頼は？」「通知確認して」「#123のdiff見せて」
  「マージ済みPR一覧」など、PRやGitHub操作に関する依頼に対して適切なghコマンドや
  gh拡張機能を使って結果を返す。PRやレビューについて聞かれたら積極的にこのスキルを使う。
context: fork
allowed-tools:
  - Bash
---

# gh PRアシスタント

ユーザーの意図を読み取り、最適なghコマンドまたはgh拡張機能を実行・案内する。
対話を通じて必要な情報を掘り下げていく。

## コマンド選択の方針

gh拡張機能を優先して使う。構造化データとして取り出す必要がある場合に限り `gh pr` コマンドを使う。

### Claudeが実行して結果を返す

| 意図 | コマンド |
|---|---|
| 自分のオープンなPR | `gh pr list --author @me --state open --json number,title,reviewDecision,reviewRequests,latestReviews,comments,updatedAt,isDraft` |
| レビュー依頼されているPR | `gh pr list --search "review-requested:@me" --state open --json number,title,author,reviewDecision,reviewRequests,latestReviews,comments,updatedAt` |
| 特定PRの詳細 | `gh pr view <number>` |
| 特定PRのdiff | `gh pr diff <number>` |
| 特定PRのCIチェック | `gh pr checks <number>` |
| 現在ブランチのPR状態 | `gh pr status` |
| GitHub通知一覧 | `gh notify -s` |

フィルターオプション（必要に応じて付加）:
- リポジトリ指定: `--repo owner/repo`
- 期間フィルター: `--search "updated:>=YYYY-MM-DD"`
- マージ済み: `--state merged`

### インタラクティブ操作として案内する

TUIやfzfを使うgh拡張機能はClaudeが実行できないため、コマンドをユーザーに案内する。

| 意図 | コマンド | 説明 |
|---|---|---|
| PRを一覧で操作したい | `gh dash` | TUIダッシュボード。diff・チェックアウト・コメントをその場で実行 |
| PRをfzfで絞り込みたい | `gh f -p` | fzfでPRを検索・チェックアウト・diff確認 |
| 通知をインタラクティブに確認 | `gh notify -w` | fzfで通知をプレビュー・既読化・ブラウザで開く |

## 結果の表示

JSONで取得したデータはテーブルに整形する。更新日時は相対時間（「2時間前」「1日前」）で表示。

### 表示カラムの構成

PR一覧には以下のカラムを**常に**表示する（値が空・0でも省略しない）。

```
| PR | タイトル | 状態 | レビュアー | 💬 | 更新 |
|----|---------|------|-----------|-----|------|
| #123 | feat: ログイン | 要対応 | alice ❌ bob ✅ charlie ⏳ | 5 | 2時間前 |
| #456 | fix: バリデーション | 承認済み | alice ✅ | 0 | 1日前 |
| #789 | feat: 検索 | レビュー待ち | — | 0 | 3日前 |
```

### 状態（reviewDecision）の表示

- `CHANGES_REQUESTED` → 要対応
- `APPROVED` → 承認済み
- `REVIEW_REQUIRED` / 空 → レビュー待ち
- `isDraft: true` → ドラフト（状態より優先）

### レビュアーカラムの構成

`latestReviews`（レビュー済み）と `reviewRequests`（依頼中・未レビュー）を合わせて表示する。

- レビュー済み（latestReviews）:
  - `APPROVED` → `名前 ✅`
  - `CHANGES_REQUESTED` → `名前 ❌`
  - `COMMENTED` → `名前 💬`
  - `DISMISSED` → `名前 ➖`
- 依頼中・未レビュー（reviewRequests） → `名前 ⏳`
- 誰も依頼されていない場合 → `—`

### コメント数の表示

`comments` 配列の長さをコメント数として表示する。0件も省略せず表示する。

## 会話の進め方

- PR番号など不足情報は自然に聞く
- 結果表示後、文脈に応じて次の操作を提案する
- インタラクティブ操作が適している場合はコマンドを案内する（実行はしない）
- レビューの実施は `/review-pr` スキルに案内する
