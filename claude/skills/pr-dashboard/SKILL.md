---
name: pr-dashboard
description: >
  自分に関連するPRの状況を一覧表示する。作成したPRのレビュー状態や、
  自分へのレビュー依頼の未対応分をテーブルで確認できる。
  「PR確認」「PR状況」「自分のPR」「やること確認」「今日のタスク」
  「レビュー依頼は？」「ダッシュボード」で発火する。
context: fork
allowed-tools:
  - Bash
  - AskUserQuestion
---

# PRダッシュボード

現在のリポジトリで自分に関連するPRの状況をテーブル表示し、次にやるべきことを把握する。

## 実行手順

### Step 1: リポジトリ情報を取得する

```bash
gh repo view --json nameWithOwner --jq '.nameWithOwner'
```

取得した値を `REPO` として記憶する。Bashの環境変数はコマンド間で保持されないため、値を直接埋め込んで使う。

### Step 2: 自分が作成したオープンなPRを取得する

過去4日間に更新されたPRを取得する（週末・連休を考慮した期間）:

```bash
gh pr list --author @me --state open \
  --search "updated:>=$(date -v-4d +%Y-%m-%d)" \
  --json number,title,reviewDecision,updatedAt,url,isDraft \
  --repo <REPO>
```

### Step 3: 自分にレビュー依頼されているPRを取得する

期間フィルターは付けない。古いレビュー依頼を見落とすと作業漏れにつながるため、未対応のものはすべて表示する:

```bash
gh pr list --search "review-requested:@me" \
  --state open \
  --json number,title,author,updatedAt,url \
  --repo <REPO>
```

### Step 4: テーブルで表示する

取得した情報を2つのセクションに分けてテーブル表示する。

#### 自分が作成したPR

```
| PR | タイトル | 状態 | 更新 |
|----|---------|------|------|
| #123 | feat: ログイン機能追加 | 要対応 | 2時間前 |
| #456 | fix: バリデーション修正 | 承認済み | 1日前 |
| #789 | feat: 検索機能 | レビュー待ち | 3日前 |
```

状態の判定:
- `isDraft: true` → ドラフト
- `reviewDecision: "CHANGES_REQUESTED"` → 要対応
- `reviewDecision: "APPROVED"` → 承認済み
- `reviewDecision: "REVIEW_REQUIRED"`または空 → レビュー待ち

#### レビュー依頼されているPR

```
| PR | タイトル | 作成者 | 更新 |
|----|---------|-------|------|
| #234 | feat: 検索API追加 | @alice | 1日前 |
```

該当するPRがない場合はそのセクションに「該当なし」と表示する。

更新日時は相対時間（「2時間前」「1日前」など）で表示すると直感的に把握しやすい。

### Step 5: アクションを提案する

テーブル表示後、AskUserQuestionツールを呼び出す:

```json
{
  "question": "PRに対してアクションを実行しますか？",
  "options": [
    { "label": "ブラウザで開く", "description": "PR番号を指定してブラウザで開く" },
    { "label": "レビューする", "description": "/review-pr でレビューを開始する" },
    { "label": "終了", "description": "何もしない" }
  ]
}
```

- **ブラウザで開く**: PR番号をAskUserQuestionで聞いて `gh pr view <number> --web --repo <REPO>` で開く
- **レビューする**: 「`/review-pr <number>`を実行してください」と案内する
- **終了**: 何もしない
