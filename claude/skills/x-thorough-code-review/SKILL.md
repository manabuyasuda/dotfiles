---
name: x-thorough-code-review
description: 状況に応じてサブエージェントを起動するコードレビューのオーケストレータです。GitHub PRまたはローカルブランチの変更をレビューします。「PRレビューして」「#123をレビュー」「このブランチをレビューして」「変更内容を見て」のように使います。PR番号が引数にない場合も起動してかまいません。
context: fork
allowed-tools:
  - Bash
  - Read
  - Glob
  - Grep
  - AskUserQuestion
  - Task
  - TaskCreate
  - TaskUpdate
  - TaskList
---

# コードレビュー

変更の状況を把握し、サブエージェントを起動して、結果を統合します。

## タスク登録

実行開始時に全ステップを`TaskCreate`で登録し、開始時に`in_progress`、完了時に`completed`へ更新します。

| # | subject | blockedBy |
|---|---------|-----------|
| 1 | レビューモードを決定する | — |
| 2 | 情報を取得する | 1 |
| 3 | 設計書を確認する | 2 |
| 4 | レビュースコープを定義する | 3 |
| 5 | 起動シグナルを算出する | 4 |
| 6 | サブエージェントを起動する | 5 |
| 7 | 結果を統合して出力する | 6 |
| 8 | レビュー後のアクション | 7 |

## 変数

| 変数 | 説明 | 設定 |
|---|---|---|
| `REVIEW_MODE` | `pr` / `local` | タスク1 |
| `PR_NUMBER` | PR番号 | タスク1 |
| `BASE_BRANCH` | ベースブランチ名 | タスク2 |
| `CHANGED_FILES` | 変更ファイル一覧（コミット済み＋コミットしていない変更） | タスク4 |
| `DIFF_SUMMARY` | 差分・探索結果の要約 | タスク2・4 |
| `DESIGN_DOC` | 設計書の要約 | タスク3 |
| `REVIEW_SIGNALS` | 起動判断用シグナル（タスク5参照） | タスク5 |

## タスク1: レビューモードを決定します

引数からPR番号を読み取ります（数字・PR URL・ブランチ名。見つからなくてもかまいません）。

AskUserQuestionでモードを選択します。PR番号が渡されていた場合は「PRベース」をデフォルトにします。

```json
{
  "question": "どちらをレビューしますか？",
  "options": [
    { "label": "PRベース", "description": "GitHub PRの差分・説明・コメント履歴を取得してレビュー" },
    { "label": "ローカル", "description": "現在のブランチのローカル変更をレビュー（PRが作成されていなくても可）" }
  ]
}
```

`REVIEW_MODE=pr`かつ`PR_NUMBER`が設定されていない場合、PR番号を確認します。

```json
{
  "question": "レビューするPRの番号またはURLを教えてください",
  "options": [
    { "label": "現在ブランチのPR", "description": "gh pr viewで現在ブランチに紐付くPRを自動検索する" }
  ]
}
```

「現在ブランチのPR」を選んだときは、以下を実行します。

```bash
PR_NUMBER=$(gh pr view --json number --jq '.number')
```

## タスク2: 情報を取得します

### `REVIEW_MODE=pr`

```bash
OWNER=$(gh repo view --json owner --jq '.owner.login')
REPO=$(gh repo view --json name --jq '.name')
gh pr view $PR_NUMBER --json number,title,body,baseRefName,headRefName,files,author,state
gh pr diff $PR_NUMBER
gh api repos/$OWNER/$REPO/pulls/$PR_NUMBER/comments \
  --jq '.[] | {path: .path, line: .original_line, body: .body, user: .user.login}'
gh api repos/$OWNER/$REPO/issues/$PR_NUMBER/comments \
  --jq '.[] | {body: .body, user: .user.login}'
CURRENT_BRANCH=$(git branch --show-current)
BASE_BRANCH=$(gh pr view $PR_NUMBER --json baseRefName --jq '.baseRefName')
```

PRの状態がOPEN以外の場合はユーザーに通知します。目的・背景・議論を`DIFF_SUMMARY`にまとめて提示します。

### `REVIEW_MODE=local`

```bash
CURRENT_BRANCH=$(git branch --show-current)
BASE_BRANCH=$(git remote show origin | awk '/HEAD branch/ {print $NF}')
git log origin/$BASE_BRANCH..HEAD --oneline
git diff origin/$BASE_BRANCH...HEAD
git status --short
git diff HEAD
```

要約を`DIFF_SUMMARY`に格納します。

## タスク3: 設計書を確認します

```json
{
  "question": "レビューの判断基準にする設計書はありますか？",
  "options": [
    { "label": "ファイルパスまたはURLを入力する", "description": "Design Doc・ADR・仕様書など" },
    { "label": "なし", "description": "設計書なしでレビューする" }
  ]
}
```

入力があれば内容を`DESIGN_DOC`に格納します。

## タスク4: レビュースコープを定義します

### 変更ファイルを確定します

```bash
COMMITTED=$(git diff --name-only origin/${BASE_BRANCH}...HEAD)
UNCOMMITTED=$(git diff --name-only HEAD)
CHANGED_FILES=$(printf '%s\n' $COMMITTED $UNCOMMITTED | grep -v '^$' | sort -u)
```

`REVIEW_MODE=pr`の場合は`gh pr diff $PR_NUMBER --name-only`と突合し、漏れを追加します。

隣接テストファイル（`.test.ts`/`.test.tsx`/`.spec.ts`/`.spec.tsx`）を追加します。`e2e/`は対象外です。

```bash
EXTRA_TESTS=""
for f in $CHANGED_FILES; do
  DIR=$(dirname "$f")
  BASE=$(basename "$f" | sed 's/\.[^.]*$//')
  for EXT in .test.ts .test.tsx .spec.ts .spec.tsx; do
    CANDIDATE="${DIR}/${BASE}${EXT}"
    if [ -f "$CANDIDATE" ] && ! echo "$CHANGED_FILES" | grep -qF "$CANDIDATE"; then
      EXTRA_TESTS="$EXTRA_TESTS $CANDIDATE"
    fi
  done
done
if [ -n "$EXTRA_TESTS" ]; then
  CHANGED_FILES="$CHANGED_FILES"$'\n'"$(echo $EXTRA_TESTS | tr ' ' '\n')"
fi
```

### 依存・使用箇所を探索します

```bash
for f in $CHANGED_FILES; do
  BASENAME=$(basename "$f" | sed 's/\.[^.]*$//')
  grep -rl "from.*['\"].*${BASENAME}['\"]" \
    --include="*.ts" --include="*.tsx" \
    --exclude-dir=node_modules --exclude-dir=.git \
    . 2>/dev/null
done | sort -u | grep -v -F -f <(echo "$CHANGED_FILES")

CHANGED_NAMES=$(git diff origin/${BASE_BRANCH}...HEAD | \
  grep '^+' | sed 's/^+//' | \
  grep -oE '(export (function|const|class) [A-Za-z][A-Za-z0-9]+|function [A-Za-z][A-Za-z0-9]+)' | \
  sed 's/export \(function\|const\|class\) //' | sort -u | head -10)

for name in $CHANGED_NAMES; do
  grep -rn "\b${name}\b" \
    --include="*.ts" --include="*.tsx" \
    --exclude-dir=node_modules --exclude-dir=.git \
    . 2>/dev/null | head -10
done
```

結果を`DIFF_SUMMARY`に追記します。

## タスク5: 起動シグナルを算出します

`CHANGED_FILES`から起動判断用のシグナルを算出し、`REVIEW_SIGNALS`に格納します。重い解析はここでは行いません。

### ファイル種別

```bash
HAS_TS_JS=$(echo "$CHANGED_FILES" | grep -qE '\.(ts|tsx|js|jsx)$' && echo true || echo false)
HAS_TSX_JSX=$(echo "$CHANGED_FILES" | grep -qE '\.(tsx|jsx)$' && echo true || echo false)
HAS_HTML=$(echo "$CHANGED_FILES" | grep -qE '\.html$' && echo true || echo false)
PACKAGE_JSON_CHANGED=$(echo "$CHANGED_FILES" | grep -qxF 'package.json' && echo true || echo false)
NON_TEST=$(echo "$CHANGED_FILES" | grep -vE '(\.test\.|\.spec\.|\.d\.ts$|tsconfig|eslint|prettier|\.config\.)' || true)
TEST_ONLY=$([ -z "$NON_TEST" ] && echo true || echo false)
```

### git履歴シグナル

重い解析の前に、データが足りるかだけを見ます。

| 分析 | 最低ライン | 信頼できるライン | 根拠 |
|---|---|---|---|
| ホットスポット | 5回 | 10回 | 5回に満たない場合は変更頻度×行数のスコアが偶然の変動と区別できません。10回以上で繰り返し触られていると判断できます |
| 書き換え率 | 10回 | 20回 | numstatの集計に複数コミットが必要です。10回に満たない場合は削除率が不安定です。削除率50%超を注意ラインとします |
| Temporal Coupling | 10件 | 20件 | 共変更ペアの検出に一定数のコミットが必要です。10件に満たない場合は偶然と区別できません |

```bash
HOTSPOT_ELIGIBLE=""
REWRITE_RATE_ELIGIBLE=""
for f in $CHANGED_FILES; do
  [ -f "$f" ] || continue
  echo "$f" | grep -qE '\.(ts|tsx|js|jsx)$' || continue
  count=$(git log --format=format: --name-only --since=12.month -- "$f" | grep -v '^\s*$' | wc -l | tr -d ' ')
  if [ "$count" -ge 5 ]; then
    lines=$(wc -l < "$f" | tr -d ' ')
    HOTSPOT_ELIGIBLE="$HOTSPOT_ELIGIBLE $f(score=$((count * lines)),count=$count)"
  fi
  if [ "$count" -ge 10 ]; then
    REWRITE_RATE_ELIGIBLE="$REWRITE_RATE_ELIGIBLE $f(count=$count)"
  fi
done

TC_COUNT=$(git log --format="%H" --since=6.month -- $CHANGED_FILES | sort -u | wc -l | tr -d ' ')
TEMPORAL_COUPLING_ELIGIBLE=$([ "$TC_COUNT" -ge 10 ] && echo true || echo false)
```

`REVIEW_SIGNALS`の例は以下の通りです。

```
has_ts_js: true/false
has_tsx_jsx: true/false
has_html: true/false
package_json_changed: true/false
test_only: true/false
hotspot_eligible: [ファイル一覧]
rewrite_rate_eligible: [ファイル一覧]
temporal_coupling_eligible: true/false
```

## タスク6: サブエージェントを起動します

`REVIEW_SIGNALS`・`CHANGED_FILES`・`DIFF_SUMMARY`・`DESIGN_DOC`を踏まえ、起動するサブエージェントを判断してTask toolで起動します。選んだサブエージェントと理由をユーザーに提示します。失敗はスキップして続行します。

各サブエージェントへは、その解析に必要なファイルだけを`Changed Files`として渡します。

```text
Repository Path: <絶対パス>
Base Branch: <BASE_BRANCH>
Changed Files: <そのサブエージェントの解析対象>
Design Doc: <DESIGN_DOC>
Diff Summary: <DIFF_SUMMARY>
Prior Findings: <先行サブエージェントの結果。必要な場合のみ>
```

## タスク7: 結果を統合して出力します

各サブエージェントの指摘をファイルパスでまとめて統合します。既存のPRコメントと重複する指摘は除外します。重要度は`must`（マージ前に修正）/ `should`（強く推奨）/ `nit`（好みの範囲）で付けます。表形式などの固定フォーマットは求めません。

`REVIEW_MODE=pr`の場合は総評にapprove / request changes / commentの推奨を含めます。git履歴の分析結果でレビューへ影響するものは、`git履歴コンテキスト`として出力します。

## タスク8: レビュー後のアクションを選びます

`REVIEW_MODE=local`の場合はスキップします。

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

「何もしない」以外が選択された場合、投稿内容を提示して承認を得てから実行します。
