---
name: x-thorough-code-review
description: コードレビューを実施する。GitHubのPRをレビューするか、ローカルブランチの変更をレビューするかを選択できる。「PRレビューして」「#123をレビュー」「このブランチをレビューして」「変更内容を見て」のように使う。PR番号が引数にない場合も起動してよい。
allowed-tools:
  - Bash
  - Read
  - Glob
  - Grep
  - AskUserQuestion
  - Agent
  - WebFetch
  - TaskCreate
  - TaskUpdate
  - TaskList
---

# コードレビュー

コードの変更をレビューします。レビューの解析・観点チェックは `code-review-engine` エージェントに委譲し、このスキルは対象の選択（PR/local）・情報取得・結果の統合・GitHubへの投稿を担います。

重い解析を独立コンテキストのエージェントに隔離することで、メインの会話のコンテキスト消費を抑えます。観点チェックの中身（カテゴリ・自動解析・適用ルール）は`code-review-engine`エージェント側で管理します。

フローは以下の通りです。

1. Step 1: レビューモードを決定する
2. Step 2: 情報を取得する
3. Step 3: code-review-engineエージェントでレビューする
4. Step 4: 結果を統合して出力する
5. Step 5: レビュー後のアクション

## タスク登録（実行開始時に必ず実施）

フローを開始する前に、全ステップを`TaskCreate`で登録します。各ステップを開始するとき`TaskUpdate`で`in_progress`へ、完了したとき`completed`へ更新します。

| # | subject | blockedBy |
|---|---------|-----------|
| 1 | Step 1: レビューモードを決定する | — |
| 2 | Step 2: 情報を取得する | 1 |
| 3 | Step 3: code-review-engine でレビューする | 2 |
| 4 | Step 4: 結果を統合して出力する | 3 |
| 5 | Step 5: レビュー後のアクション | 4 |

## 変数

実行を通じて以下の変数を使い回します。各ステップで設定し、後続のステップで参照します。

| 変数 | 説明 | 設定タイミング |
|---|---|---|
| `REVIEW_MODE` | `pr` / `local` | Step 1 |
| `PR_NUMBER` | PR番号 | Step 1 |
| `OWNER` | リポジトリオーナー名 | Step 2A |
| `REPO` | リポジトリ名 | Step 2A |
| `CURRENT_BRANCH` | 現在のブランチ名 | Step 2A / 2B |
| `BASE_BRANCH` | ベースブランチ名 | Step 2A / 2B |
| `REVIEW_COMMENTS` | 既存のレビュー・会話コメント | Step 2A |
| `DESIGN_DOC` | 設計書のパスまたは内容 | Step 2C |

## Step 1: レビューモードを決定する

### 1-1. 引数からPR番号を読み取る（あれば）

引数中の数字、GitHub PR URL、またはブランチ名からPR番号を特定し、`PR_NUMBER`に格納します。見つからなくてもかまいません。

### 1-2. AskUserQuestionでレビューモードを選択する

```json
{
  "question": "どちらをレビューしますか？",
  "options": [
    { "label": "PRベース", "description": "GitHub PRの差分・説明・コメント履歴を取得してレビュー" },
    { "label": "ローカル", "description": "現在のブランチのローカル変更をレビュー（PR未作成でも可）" }
  ]
}
```

PR番号が引数で渡されていた場合は「PRベース」をデフォルト選択肢として提示します。選択結果を`REVIEW_MODE`に格納します（`pr` / `local`）。

### 1-3. `REVIEW_MODE=pr`かつ`PR_NUMBER`が未設定の場合

AskUserQuestionでPR番号を確認します。

```json
{
  "question": "レビューするPRの番号またはURLを教えてください",
  "options": [
    { "label": "現在ブランチのPR", "description": "gh pr viewで現在ブランチに紐付くPRを自動検索する" }
  ]
}
```

「現在ブランチのPR」が選択された場合は以下のコマンドを実行します。

```bash
PR_NUMBER=$(gh pr view --json number --jq '.number')
```

## Step 2A: PR情報を取得する（`REVIEW_MODE=pr`の場合）

```bash
OWNER=$(gh repo view --json owner --jq '.owner.login')
REPO=$(gh repo view --json name --jq '.name')
```

PRの基本情報を取得します。

```bash
gh pr view $PR_NUMBER --json number,title,body,baseRefName,headRefName,files,author,state
```

- タイトル・説明・ベースブランチ・ヘッドブランチ・変更ファイル一覧を把握します
- PRの状態がOPEN以外の場合はユーザーに通知します（レビュー自体は続行してかまいません）

ベースブランチとヘッドブランチを設定します。

```bash
BASE_BRANCH=$(gh pr view $PR_NUMBER --json baseRefName --jq '.baseRefName')
HEAD_BRANCH=$(gh pr view $PR_NUMBER --json headRefName --jq '.headRefName')
CURRENT_BRANCH=$(git branch --show-current)
```

`code-review-engine`エージェントは`origin/<BASE_BRANCH>...HEAD`を解析するため、現在のブランチがPRのヘッドでない場合はチェックアウトします。

```bash
if [ "$CURRENT_BRANCH" != "$HEAD_BRANCH" ]; then
  gh pr checkout $PR_NUMBER
fi
```

既存のレビューコメントと会話コメントを取得し、`REVIEW_COMMENTS`に保持します（エージェントに渡して重複指摘を除外させます）。

```bash
gh api repos/$OWNER/$REPO/pulls/$PR_NUMBER/comments \
  --jq '.[] | {path: .path, line: .original_line, body: .body, user: .user.login}'
gh api repos/$OWNER/$REPO/issues/$PR_NUMBER/comments \
  --jq '.[] | {body: .body, user: .user.login}'
```

取得した情報をもとに、PRの目的・背景・これまでの議論を整理してユーザーに提示します。

## Step 2B: ローカル情報を取得する（`REVIEW_MODE=local`の場合）

```bash
CURRENT_BRANCH=$(git branch --show-current)
BASE_BRANCH=$(git remote show origin | awk '/HEAD branch/ {print $NF}')
```

コミット一覧を取得します（変更の意図を把握）。

```bash
git log origin/$BASE_BRANCH..HEAD --oneline
```

`REVIEW_COMMENTS`は空のままにします。

## Step 2C: 設計書を確認する

AskUserQuestionでファイルパスまたはURLを尋ねます。

```json
{
  "question": "レビューの判断基準にする設計書はありますか？",
  "options": [
    { "label": "ファイルパスまたはURLを入力する", "description": "Design Doc・ADR・仕様書など" },
    { "label": "なし", "description": "設計書なしでレビューする" }
  ]
}
```

ファイルパスまたはURLが入力された場合は`DESIGN_DOC`に格納します。エージェントが判断基準に加えます。

## Step 3: code-review-engine エージェントでレビューする

`Agent`ツールで`code-review-engine`エージェントを起動し、以下を渡します。

```
Agent: code-review-engine
引数:
- BASE_BRANCH: <BASE_BRANCH>
- 設計書: <DESIGN_DOC（なければ省略）>
- 既存レビューコメント: <REVIEW_COMMENTS（なければ省略）>
```

エージェントは差分の取得・自動解析・観点レビューを独立コンテキストで実行し、「レビュー指摘事項」と「git履歴コンテキスト」を構造化して返します。

`code-review-engine`が起動できない場合は、その旨をユーザーに伝え、エージェントの定義（`agents/code-review-engine.md`）にしたがって手動でレビューします。

## Step 4: 結果を統合して出力する

エージェントが返した指摘事項とgit履歴コンテキストに、モード別のサマリーと総評を付けて出力します。

### サマリー（モード別）

`REVIEW_MODE=pr`の場合

```
## PRサマリー
- **タイトル**: <タイトル>
- **作成者**: <作成者>
- **ベースブランチ**: <base> ← <head>
- **変更ファイル数**: <N>ファイル
```

`REVIEW_MODE=local`の場合

```
## ブランチサマリー
- **ブランチ**: <current-branch>
- **ベース**: <base-branch>
- **コミット数**: <N>件
- **変更ファイル数**: <N>ファイル
```

### レビュー指摘事項・git履歴コンテキスト

`code-review-engine`が返した内容をそのまま掲載します。

### 総評

```
## 総評
<変更全体の評価>
<REVIEW_MODE=prの場合: approve / request changes / commentの推奨>
```

## Step 5: レビュー後のアクション（`REVIEW_MODE=pr`のみ）

`REVIEW_MODE=local`の場合はこのステップをスキップします。

AskUserQuestionで次のアクションを選択してもらいます。

```json
{
  "question": "レビュー結果をどうしますか？",
  "options": [
    { "label": "approve", "description": "gh pr review --approveで承認する" },
    { "label": "request changes", "description": "gh pr review --request-changesで変更リクエストする" },
    { "label": "comment", "description": "gh pr review --commentでコメントのみ投稿する" },
    { "label": "何もしない", "description": "GitHubへの投稿はしない" }
  ]
}
```

「何もしない」以外が選択された場合、投稿内容を表示してユーザーの承認を得てから実行します。

## 注意事項

- PRの作成者への敬意を忘れず、建設的なフィードバックを心がけます
- レビュー観点・自動解析・適用ルールの追加や変更は、このスキルではなく`code-review-engine`エージェント（`agents/code-review-engine.md`）で行います
