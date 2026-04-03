---
name: code-review
description: コードレビューを実施する。GitHubのPRをレビューするか、ローカルブランチの変更をレビューするかを選択できる。「PRレビューして」「#123をレビュー」「このブランチをレビューして」「変更内容を見て」のように使う。PR番号が引数にない場合も起動してよい。
context: fork
allowed-tools:
  - Bash
  - Read
  - Glob
  - Grep
  - AskUserQuestion
  - Skill
  - WebFetch
---

# コードレビュー

コード差分・変更の意図・設計書をもとにレビューを実施する。

フロー:

1. Step 1: レビューモードを決定する
2. Step 2A / 2B: 情報を取得する
3. Step 2C: 設計書を確認する
4. Step 3: レビュースコープを定義する
5. Step 4: 自動解析を実行する
6. Step 5: コードレビューを実施する
7. Step 6: 結果を統合して出力する
8. Step 7: レビュー後のアクション

---

## 変数

実行を通じて以下の変数を使い回す。各ステップで設定し、後続のステップで参照する。

| 変数 | 説明 | 設定タイミング |
|---|---|---|
| `REVIEW_MODE` | `pr` / `local` | Step 1 |
| `PR_NUMBER` | PR番号 | Step 1 |
| `OWNER` | リポジトリオーナー名 | Step 2A |
| `REPO` | リポジトリ名 | Step 2A |
| `CURRENT_BRANCH` | 現在のブランチ名 | Step 2A / 2B |
| `BASE_BRANCH` | ベースブランチ名 | Step 2A / 2B |
| `CHANGED_FILES` | 変更ファイル一覧（改行区切り） | Step 3 |

---

## Step 1: レビューモードを決定する

### 1-1. 引数からPR番号を読み取る（あれば）

引数中の数字、GitHub PR URL、またはブランチ名からPR番号を特定し、`PR_NUMBER`に格納する。見つからなくてもよい。

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

PR番号が引数で渡されていた場合は「PRベース」をデフォルト選択肢として提示する。選択結果を`REVIEW_MODE`に格納する（`pr` / `local`）。

### 1-3. `REVIEW_MODE=pr`かつ`PR_NUMBER`が未設定の場合

```json
{
  "question": "レビューするPRの番号またはURLを教えてください",
  "options": [
    { "label": "現在ブランチのPR", "description": "gh pr viewで現在ブランチに紐付くPRを自動検索する" }
  ]
}
```

「現在ブランチのPR」が選択された場合:

```bash
PR_NUMBER=$(gh pr view --json number --jq '.number')
```

---

## Step 2A: PR情報を取得する（`REVIEW_MODE=pr`の場合）

```bash
OWNER=$(gh repo view --json owner --jq '.owner.login')
REPO=$(gh repo view --json name --jq '.name')
```

PRの基本情報を取得する。

```bash
gh pr view $PR_NUMBER --json number,title,body,baseRefName,headRefName,files,author,state
```

- タイトル・説明・ベースブランチ・ヘッドブランチ・変更ファイル一覧を把握する
- PRの状態がOPEN以外の場合はユーザーに通知する（レビュー自体は続行してよい）

コード差分を取得する。

```bash
gh pr diff $PR_NUMBER
```

既存のレビューコメントを取得する。

```bash
gh api repos/$OWNER/$REPO/pulls/$PR_NUMBER/comments \
  --jq '.[] | {path: .path, line: .original_line, body: .body, user: .user.login}'
```

会話コメントを取得する。

```bash
gh api repos/$OWNER/$REPO/issues/$PR_NUMBER/comments \
  --jq '.[] | {body: .body, user: .user.login}'
```

ベースブランチを設定する。

```bash
CURRENT_BRANCH=$(git branch --show-current)
BASE_BRANCH=$(gh pr view $PR_NUMBER --json baseRefName --jq '.baseRefName')
```

取得した情報をもとに、PRの目的・背景・これまでの議論を整理してユーザーに提示する。

---

## Step 2B: ローカル情報を取得する（`REVIEW_MODE=local`の場合）

```bash
CURRENT_BRANCH=$(git branch --show-current)
BASE_BRANCH=$(git remote show origin | awk '/HEAD branch/ {print $NF}')
```

コミット一覧を取得する（変更の意図を把握）。

```bash
git log origin/$BASE_BRANCH..HEAD --oneline
```

ブランチ全体の差分を取得する（コミット済み変更）。

```bash
git diff origin/$BASE_BRANCH...HEAD
```

未コミット変更を取得する（あれば含める）。

```bash
git status --short
git diff HEAD
```

---

## Step 2C: 設計書を確認する

AskUserQuestionでファイルパスまたはURLを尋ねる。

```json
{
  "question": "レビューの判断基準にする設計書はありますか？",
  "options": [
    { "label": "ファイルパスまたはURLを入力する", "description": "Design Doc・ADR・仕様書など" },
    { "label": "なし", "description": "設計書なしでレビューする" }
  ]
}
```

ファイルパスが入力された場合はそのファイルを読み、URLが入力された場合は内容を取得して、変更の意図・制約・設計方針をコンテキストに加える。

---

## Step 3: レビュースコープを定義する

### 3-1. 変更ファイルを確定する

```bash
CHANGED_FILES=$(git diff --name-only origin/${BASE_BRANCH}...HEAD)
echo "$CHANGED_FILES"
```

### 3-2. 直接依存するファイルを探索する

変更ファイルのベース名（拡張子除く）を使って、importしているファイルをgrepで検索する。

```bash
for f in $CHANGED_FILES; do
  BASENAME=$(basename "$f" | sed 's/\.[^.]*$//')
  grep -rl "from.*['\"].*${BASENAME}['\"]" \
    --include="*.ts" --include="*.tsx" \
    --exclude-dir=node_modules --exclude-dir=.git \
    . 2>/dev/null
done | sort -u | grep -v -F -f <(echo "$CHANGED_FILES")
```

### 3-3. 変更した関数・コンポーネントの使用箇所を探索する

差分から追加・変更された関数名・コンポーネント名を抽出し、使用箇所を最大10件探索する。意図しない使われ方・設計的に問題のある使われ方がないかを確認する。

```bash
CHANGED_NAMES=$(git diff origin/${BASE_BRANCH}...HEAD | \
  grep '^+' | sed 's/^+//' | \
  grep -oE '(export (function|const|class) [A-Za-z][A-Za-z0-9]+|function [A-Za-z][A-Za-z0-9]+)' | \
  sed 's/export \(function\|const\|class\) //' | sort -u | head -10)

for name in $CHANGED_NAMES; do
  echo "=== ${name} の使用箇所 ==="
  grep -rn "\b${name}\b" \
    --include="*.ts" --include="*.tsx" \
    --exclude-dir=node_modules --exclude-dir=.git \
    . 2>/dev/null | head -10
done
```

探索の成功条件: `CHANGED_NAMES`に1件以上の名前が抽出でき、かつそれぞれの使用箇所が1件以上見つかること。

- `CHANGED_NAMES`が空の場合 — 差分に`export function` / `export const` / `function`の形式が含まれていない（クラスメソッド・アロー関数の再代入・型定義のみの変更など）。このときは差分を直接読んで関数名・コンポーネント名を手動で特定し、同様に`grep -rn`で使用箇所を検索する
- 使用箇所が0件の場合 — 新規追加で未使用、またはバレルエクスポート経由で参照されている可能性がある。`knip --exports`の結果と照合して判断する

---

## Step 4: 自動解析を実行する

変更ファイルの種類に応じて該当するCLIを実行する。ツール未インストール・コマンドエラーの場合はスキップして次に進む。

### 循環参照・依存数（.ts / .tsx / .js / .jsxが含まれる場合）

```bash
CHANGED_DIRS=$(echo "$CHANGED_FILES" | xargs -I{} dirname {} | sort -u)
echo "$CHANGED_DIRS" | xargs -I{} madge --circular --ts-config tsconfig.json {} 2>/dev/null
echo "$CHANGED_FILES" | grep -E '\.(ts|tsx|js|jsx)$' | xargs madge --summary 2>/dev/null
```

### 未使用エクスポート（.ts / .tsx / .js / .jsxが含まれる場合）

```bash
knip --exports 2>/dev/null | head -30
```

### セキュリティ静的解析（.ts / .tsx / .js / .jsxが含まれる場合）

```bash
CHANGED_JS=$(echo "$CHANGED_FILES" | grep -E '\.(ts|tsx|js|jsx)$' | xargs echo)
[ -n "$CHANGED_JS" ] && semgrep scan \
  --config p/typescript --config p/react --config p/owasp-top-ten \
  --severity=ERROR --severity=WARNING --no-rewrite-rule-ids \
  $CHANGED_JS 2>/dev/null
```

### ドメイン層純粋性チェック（domain/**/*.tsが含まれる場合）

```bash
CHANGED_DOMAIN=$(echo "$CHANGED_FILES" | grep -E 'domain/.*\.ts$' | xargs echo)
[ -n "$CHANGED_DOMAIN" ] && grep -n "import.*[Rr]eact\|JSX\.Element\|React\.ReactNode\|useState\|useEffect\|useCallback\|useMemo" \
  $CHANGED_DOMAIN 2>/dev/null
```

### CVE・サプライチェーンリスク（package.jsonが変更された場合）

```bash
npm audit --audit-level=moderate 2>/dev/null | head -30
socket ci 2>/dev/null | head -30
```

### バンドルサイズ（package.jsonが変更された場合）

ビルドツールを検出してバンドルアナライザーを実行する。アナライザーが未インストールの場合はスキップする。

```bash
# ビルドツールを検出
if grep -q '"next"' package.json 2>/dev/null; then
  BUILD_TOOL="nextjs"
elif grep -q '"vite"' package.json 2>/dev/null; then
  BUILD_TOOL="vite"
else
  BUILD_TOOL="unknown"
fi

case "$BUILD_TOOL" in
  nextjs)
    # @next/bundle-analyzerが設定済みの場合のみ実行
    if grep -q '"@next/bundle-analyzer"' package.json 2>/dev/null; then
      ANALYZE=true npm run build 2>/dev/null | tail -30
    else
      echo "bundle-analyzer未設定（@next/bundle-analyzerをインストールして設定することで有効化できます）"
    fi
    ;;
  vite)
    # rollup-plugin-visualizerが設定済みの場合のみ実行
    if grep -q '"rollup-plugin-visualizer"' package.json 2>/dev/null; then
      npm run build 2>/dev/null | tail -20
    else
      echo "bundle-analyzer未設定（rollup-plugin-visualizerをインストールしてvite.configに追加することで有効化できます）"
    fi
    ;;
esac
```

### アクセシビリティ静的解析（.tsx / .jsxが含まれる場合）

```bash
CHANGED_JSX=$(echo "$CHANGED_FILES" | grep -E '\.(tsx|jsx)$' | xargs echo)
[ -n "$CHANGED_JSX" ] && npx markuplint $CHANGED_JSX 2>/dev/null
```

### React診断（.tsx / .jsxが含まれる場合）

#### react-doctorによる自動診断

```bash
npx -y react-doctor@latest $CHANGED_JSX --verbose 2>/dev/null | head -120
```

コマンドが失敗した場合はスキップする。

#### Vercel React Best Practices

Skillツールで`vercel-react-best-practices`を適用する。スキルが起動できない場合は[vercel-labsにあるファイル](https://github.com/vercel-labs/agent-skills/tree/main/skills/react-best-practices)を参照して実行する。

```
Skill: vercel-react-best-practices
引数: 以下のコードをVercelのReactベストプラクティスの観点でレビューしてください。<対象コード>
```

#### Vercel Composition Patterns

Skillツールで`vercel-composition-patterns`を適用する。スキルが起動できない場合は[vercel-labsにあるファイル](https://github.com/vercel-labs/agent-skills/tree/main/skills/composition-patterns)を参照して実行する。

```
Skill: vercel-composition-patterns
引数: 以下のコードをVercelのCompositionパターンの観点でレビューしてください。<対象コード>
```

---

## Step 5: コードレビューを実施する

**Step 4が完了してから着手する。**

「コードレビュー」はClaude Codeが差分を直接読んで行う評価を指す。Step 4の「自動解析」（CLIツール出力）とは区別して使用する。

### カテゴリ

指摘に紐づけるカテゴリは以下の8つ。1つの指摘に複数のカテゴリを付与してよい。

| カテゴリ | 判断基準 |
|---|---|
| `[ロジック]` | 実行時に正しく動くか。null参照・await忘れ・競合状態など、動作が誤っているまたはクラッシュする可能性がある問題 |
| `[設計]` | コードの構造・責務の分担が適切か。UIとロジックの混在・コンポーネントの肥大化・依存関係のもつれなど、正しく動いていても将来の変更が難しくなる問題 |
| `[型]` | TypeScriptの型で正しくモデル化されているか。`as`の乱用・暗黙的any・Union型の網羅漏れなど、型システムが実際の値の形を正確に表現していない問題（コンパイルは通っても型が嘘をついている状態） |
| `[パフォーマンス]` | 不要な処理・再レンダリングが発生していないか。インライン生成・ループ内検索・バンドルサイズ増加など |
| `[セキュリティ]` | 攻撃に悪用できる実装になっていないか。XSS・認証情報の漏洩・フロントのみの権限チェックなど |
| `[テスト]` | 変更に対してテストが十分か。テスト不足・実装詳細への依存・エッジケース漏れなど |
| `[A11Y]` | すべてのユーザーが操作できるか。セマンティクス不足・aria属性漏れ・キーボード操作の欠如など |
| `[その他]` | 上記いずれにも当てはまらない指摘 |

### 5-1. 自動解析結果の整理

Step 4で取得した全ツール・全スキルの出力から指摘を抽出し、同一または実質同じ内容はひとつの項目に集約する。各項目には該当するカテゴリを複数付与してよい。出力がない場合は省略する。

```
- <指摘内容> [`[カテゴリ1]` `[カテゴリ2]`]
  出典: <madge / knip / semgrep / npm audit / socket / バンドルアナライザー / react-doctor / markuplint / Vercel React Best Practices / Vercel Composition Patterns>
```

### 5-2. コードレビュー

差分・スコープファイルを読み、自動解析では検出できない問題を中心にコードレビューを実施する。条件に該当するカテゴリはスキップする。

#### 適用条件

| カテゴリ | 適用条件 |
|---|---|
| `[ロジック]` | .ts / .tsx / .js / .jsxが含まれる |
| `[設計]` | .ts / .tsx / .js / .jsxが含まれる |
| `[型]` | .ts / .tsxが含まれる |
| `[パフォーマンス]` | .ts / .tsx / .js / .jsxが含まれ、かつテスト・設定ファイルのみでない |
| `[セキュリティ]` | テストファイル以外が含まれる |
| `[テスト]` | 設定ファイル・型定義以外が含まれる |
| `[A11Y]` | .tsx / .jsx / .htmlが含まれる |

---

### チェック項目

Step 4の自動解析で検知できないもの、およびプロジェクト固有の判断が必要なものに絞って確認する。

#### [ロジック]

なし。

#### [設計]

なし。

#### [型]

なし。

#### [パフォーマンス]

なし。

#### [セキュリティ]

なし。

#### [テスト]

なし。

#### [A11Y]

なし。

---

## Step 6: 結果を統合して出力する

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
- **未コミット変更**: あり / なし
```

### レビュー指摘事項

各指摘をファイルパスでソートして統合する。同じファイルへの複数の指摘はファイルごとにまとめる。既存のレビューコメントと重複する指摘は除外する。

```
## レビュー指摘事項

### <ファイルパス>

**L<行番号>** [<重要度>] `[<カテゴリ>]` <指摘内容>
> <該当コードの引用>
<理由と改善案>
```

重要度:

- **must** — バグ・セキュリティリスクなど、マージ前に修正が必要
- **should** — 設計・可読性の改善など、強く推奨
- **nit** — 些細な改善提案、好みの範囲

カテゴリはStep 5で定義したカテゴリを使用する。

### 総評

```
## 総評
<変更全体の評価>
<REVIEW_MODE=prの場合: approve / request changes / commentの推奨>
```

---

## Step 7: レビュー後のアクション（`REVIEW_MODE=pr`のみ）

`REVIEW_MODE=local`の場合はこのステップをスキップする。

AskUserQuestionで次のアクションを選択してもらう。

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

「何もしない」以外が選択された場合、投稿内容を表示してユーザーの承認を得てから実行する。

---

## 注意事項

- PRの差分が大きい場合は、変更ファイルをカテゴリ別に整理して段階的にレビューする
- CLIツールがエラーになった場合はスキップしてコードレビューを優先する
- PRの作成者への敬意を忘れず、建設的なフィードバックを心がける
