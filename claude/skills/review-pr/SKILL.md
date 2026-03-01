---
name: review-pr
description: コードレビューを実施する。GitHubのPRをレビューするか、ローカルブランチの変更をレビューするかを選択できる。「PRレビューして」「#123をレビュー」「このブランチをレビューして」「変更内容を見て」のように使う。PR番号が引数にない場合も起動してよい。
context: fork
allowed-tools:
  - Bash
  - Read
  - Glob
  - Grep
  - AskUserQuestion
---

# コードレビュー

コード差分・変更の意図・既存コメントを元にレビューを実施する。

**フロー**: モード選択 → 情報収集 → レビュー実施 → 結果表示 → アクション選択

---

## 変数

実行を通じて以下の変数を使い回す。各ステップで設定し、後続のコマンドで参照する。

| 変数 | 説明 | 値 | 設定タイミング |
|---|---|---|---|
| `REVIEW_MODE` | レビューモード | `pr` / `local` | Step 1 |
| `PR_NUMBER` | レビュー対象のPR番号 | 数値 | Step 1 |
| `OWNER` | リポジトリオーナー名 | 文字列 | Step 2A |
| `REPO` | リポジトリ名 | 文字列 | Step 2A |
| `CURRENT_BRANCH` | 現在のブランチ名 | 文字列 | Step 2A / 2B |
| `PR_HEAD` | PRのheadブランチ名 | 文字列 | Step 2A |
| `BASE_BRANCH` | ローカルレビューのベースブランチ名 | 文字列 | Step 2B |

---

## 実行手順

### Step 1: レビューモードを決定する

#### 1-1. 引数からPR番号を読み取る（あれば）

引数中の数字、GitHub PR URL、またはブランチ名からPR番号を特定し、`PR_NUMBER` に格納する。見つからなくてもよい。

#### 1-2. AskUserQuestionでレビューモードを選択する

```json
{
  "question": "どちらをレビューしますか？",
  "options": [
    {
      "label": "PRベース",
      "description": "GitHub PRの差分・説明・コメント履歴を取得してレビュー"
    },
    {
      "label": "ローカル",
      "description": "現在のブランチのローカル変更をレビュー（PR未作成でも可）"
    }
  ]
}
```

PR番号が引数で渡されていた場合は「PRベース」をデフォルト選択肢として提示する。選択結果を `REVIEW_MODE` に格納する（`pr` / `local`）。

#### 1-3. `REVIEW_MODE=pr` かつ `PR_NUMBER` が未設定の場合

```json
{
  "question": "レビューするPRの番号またはURLを教えてください",
  "options": [
    { "label": "現在ブランチのPR", "description": "gh pr view で現在ブランチに紐付くPRを自動検索する" }
  ]
}
```

「現在ブランチのPR」が選択された場合は以下で `PR_NUMBER` を設定する:

```bash
PR_NUMBER=$(gh pr view --json number --jq '.number')
```

---

### Step 2A: PR情報を取得する（`REVIEW_MODE=pr` の場合）

**残りの変数を設定する（`PR_NUMBER` は Step 1 で設定済み）:**

```bash
OWNER=$(gh repo view --json owner --jq '.owner.login')
REPO=$(gh repo view --json name --jq '.name')
```

**PRの基本情報を取得:**

```bash
gh pr view $PR_NUMBER --json number,title,body,baseRefName,headRefName,files,author,state
```

- タイトル、説明、ベースブランチ、ヘッドブランチ、変更ファイル一覧を把握する
- PRの状態がOPEN以外の場合はユーザーに通知する（レビュー自体は続行してよい）

**コード差分を取得:**

```bash
gh pr diff $PR_NUMBER
```

**既存のレビューコメントを取得:**

```bash
gh api repos/$OWNER/$REPO/pulls/$PR_NUMBER/comments \
  --jq '.[] | {path: .path, line: .original_line, body: .body, user: .user.login}'
```

**会話コメント（議論の経緯）を取得:**

```bash
gh api repos/$OWNER/$REPO/issues/$PR_NUMBER/comments \
  --jq '.[] | {body: .body, user: .user.login}'
```

**現在ブランチとPRブランチを照合する:**

```bash
CURRENT_BRANCH=$(git branch --show-current)
PR_HEAD=$(gh pr view $PR_NUMBER --json headRefName --jq '.headRefName')
```

- 一致する場合: ローカルファイルを直接参照してより深いレビューが可能
- 一致しない場合: 差分のみでレビュー（`gh pr checkout $PR_NUMBER` で深いレビューも可能と案内）

取得した情報をもとに、PRの目的・背景・これまでの議論を整理してユーザーに提示する。

---

### Step 2B: ローカル情報を取得する（`REVIEW_MODE=local` の場合）

**現在のブランチとベースブランチを特定する:**

```bash
CURRENT_BRANCH=$(git branch --show-current)
BASE_BRANCH=$(git remote show origin | awk '/HEAD branch/ {print $NF}')
```

**コミット一覧を取得する（変更の意図を把握）:**

```bash
git log origin/$BASE_BRANCH..HEAD --oneline
```

**ブランチ全体の差分を取得する（コミット済み変更）:**

```bash
git diff origin/$BASE_BRANCH...HEAD
```

**未コミット変更を取得する（あれば含める）:**

```bash
git status --short
git diff HEAD
```

**変更ファイル一覧を取得する:**

```bash
git diff --name-only origin/$BASE_BRANCH...HEAD
```

ローカルファイルは直接参照できるため、差分だけでは分からない周辺コンテキストも積極的に確認する:

**呼び出し元・依存元を特定する（Grep）:**

```bash
# 変更した関数・クラス・エクスポートを利用している箇所を検索
grep -r "<関数名 or クラス名>" --include="*.ts"
```

**型定義・interface を追跡する（Glob + Read）:**

```bash
# 型定義ファイルを検索
find src/types -name "*.ts"
# または tsconfig.json の paths 設定を確認
```

**設定ファイルとの整合性を確認する（Read）:**

変更内容に応じて関連する設定ファイルを読む:
- `package.json` — 依存関係・スクリプト
- `tsconfig.json` — パス設定・コンパイルオプション
- `.env.example` — 環境変数の追加漏れ

**静的解析ツールで補完する（JS/TSプロジェクトの場合）:**

変更ファイルを起点にして対象範囲を限定する。モノレポや大規模プロジェクトでプロジェクト全体を解析すると広すぎるため。各ツールは失敗してもスキップしてよい。

```bash
# 変更ファイルの一覧とそのディレクトリを取得（スコープの基点）
CHANGED_FILES=$(git diff --name-only origin/$BASE_BRANCH...HEAD | grep -E '\.(ts|tsx|js|jsx)$')
CHANGED_DIRS=$(echo "$CHANGED_FILES" | xargs -I{} dirname {} | sort -u)
```

```bash
# 循環参照の検出（変更ファイルを含むディレクトリに限定）
echo "$CHANGED_DIRS" | xargs -I{} madge --circular --ts-config tsconfig.json {} 2>/dev/null

# 変更ファイルの依存数確認（責務が増えすぎていないか）
echo "$CHANGED_FILES" | xargs madge --summary 2>/dev/null

# 変更ファイルに影響を受けるモジュールの把握（影響範囲の可視化）
echo "$CHANGED_FILES" | xargs -I{} depcruise --affected {} -T dot 2>/dev/null | head -30

# 未使用エクスポートの検出（削除・リネームで生じた孤立がないか）
knip --reporter compact 2>/dev/null | grep -F "$(echo "$CHANGED_FILES" | tr '\n' '\|')"

# 型カバレッジ（変更ファイルのany型混入がないか）
echo "$CHANGED_FILES" | xargs type-coverage --detail --strict --show-relative-path 2>/dev/null

# アンチパターン・セキュリティ検出（変更ファイルのみ）
semgrep scan --config p/typescript --config p/react \
  --severity=ERROR --severity=WARNING \
  --no-rewrite-rule-ids \
  $(echo "$CHANGED_FILES" | tr '\n' ' ') 2>/dev/null
```

---

### Step 3: レビューを実施する

差分・コミット履歴・ローカルファイルを読み、以下の観点でレビューコメントを作成する。

`vercel-react-best-practices` スキルのルールも参照して、Vercel 公式のベストプラクティスに照らした指摘を加える。

1. **バグ・ロジックの問題**
   - オフバイワンエラー、null/undefined参照、境界値の見落とし
   - 非同期処理の競合状態・エラーハンドリングの漏れ
   - イベントハンドラの二重実行・クリーンアップ漏れ（useEffect等）

2. **コンポーネント設計・アーキテクチャ**
   - 単一責務になっているか（UIとロジックが混在していないか）
   - propsのインターフェースは適切か（過剰・不足・命名の一貫性）
   - Container/Presentationalの分離、カスタムフックへの切り出しが適切か
   - 再利用性・compositionパターンの観点で過度に特化していないか
   - 既存のコンポーネント・ユーティリティと重複していないか

3. **状態管理**
   - ローカル状態とグローバル状態の使い分けが適切か
   - prop drillingが発生していないか
   - 派生状態を冗長に持っていないか（useMemoで計算できるものをstateにしていないか）
   - フォームの状態管理方法がプロジェクトの方針と一致しているか

4. **パフォーマンス**
   - 不要な再レンダリングが発生していないか（memo/useMemo/useCallbackの適切な使用）
   - リストのkeyが安定した一意の値を使っているか
   - 重いコンポーネントの遅延ロード（lazy/Suspense）が考慮されているか
   - 新たに追加したnpmパッケージのバンドルサイズ影響（`bundle-phobia <package>` で確認）

5. **型安全性**
   - `any`型・型アサション（`as`）の不必要な使用がないか
   - イベントハンドラ・APIレスポンスの型が正確に定義されているか
   - ジェネリクスの活用で型の重複定義を避けられているか

6. **アクセシビリティ**
   - セマンティックなHTML要素を使っているか（`div`でボタンを作っていないか等）
   - インタラクティブ要素にARIAラベル・ロールが適切に付与されているか
   - キーボード操作・フォーカス管理が考慮されているか
   - 色のみで情報を伝えていないか

7. **セキュリティリスク**
   - `dangerouslySetInnerHTML` 等のXSSリスク
   - 機密情報のハードコード・フロントエンドへの露出
   - 認証・認可チェックのバイパスリスク

8. **テストの妥当性**
   - 変更に対応するテストが追加されているか
   - ユーザー操作ベースのテストになっているか（実装詳細に依存していないか）
   - エッジケース（空配列・null・エラー状態）がカバーされているか

---

### Step 4: レビュー結果を出力する

**GitHubへの自動投稿はしない。**

#### サマリー（モード別）

**`REVIEW_MODE=pr` の場合:**

```
## PRサマリー
- **タイトル**: <タイトル>
- **作成者**: <作成者>
- **ベースブランチ**: <base> ← <head>
- **変更ファイル数**: <N>ファイル
```

**`REVIEW_MODE=local` の場合:**

```
## ブランチサマリー
- **ブランチ**: <current-branch>
- **ベース**: <base-branch>
- **コミット数**: <N>件
- **変更ファイル数**: <N>ファイル
- **未コミット変更**: あり / なし
```

#### レビュー指摘事項（共通）

```
## レビュー指摘事項

### <ファイルパス>

**L<行番号>** [<重要度>] <指摘内容>
> <該当コードの引用>
<理由と改善案>
```

重要度は以下の3段階:

- **must**: バグ、セキュリティリスクなど、マージ前に修正が必要
- **should**: 可読性や設計の改善など、強く推奨
- **nit**: 些細な改善提案、好みの範囲

#### 総評（共通）

```
## 総評
<変更全体の評価>
<REVIEW_MODE=pr の場合: approve / request changes / comment の推奨>
```

---

### Step 5: レビュー後のアクション（`REVIEW_MODE=pr` のみ）

`REVIEW_MODE=local` の場合はこのステップをスキップする。

AskUserQuestionで次のアクションを選択してもらう:

```json
{
  "question": "レビュー結果をどうしますか？",
  "options": [
    { "label": "approve", "description": "gh pr review --approve で承認する" },
    { "label": "request changes", "description": "gh pr review --request-changes で変更リクエストする" },
    { "label": "comment", "description": "gh pr review --comment でコメントのみ投稿する" },
    { "label": "何もしない", "description": "GitHubへの投稿はしない" }
  ]
}
```

「何もしない」以外が選択された場合、投稿内容を表示してユーザーの承認を得てから実行する。

---

## 注意事項

- PRの差分が大きい場合は、変更ファイルをカテゴリ別に整理して段階的にレビューする
- 既存のレビューコメントと重複する指摘は避ける
- PRの作成者への敬意を忘れず、建設的なフィードバックを心がける
