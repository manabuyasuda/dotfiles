---
name: x-code-review-static
description: 静的解析ツールによる決定論的なコードレビューを実施します。リポジトリの設定ファイルから使えるツールを検出して実行し、lefthook・CIで実行済みのチェックはスキップします。「静的解析して」「ツールでチェックして」「static review」のように使います。AIの判断によるレビューはx-code-review-judgment、git履歴の分析はx-code-review-git-historyが担当します。
context: fork
allowed-tools:
  - Bash
  - Read
  - Glob
  - Grep
---

# 静的解析レビュー

機械が決定論的に検出できる問題をツールの実行で洗い出します。AIの判断を挟まず、ツールの出力をそのまま整理して報告します。

## Step 1: 変更ファイルを確定する

```bash
CURRENT_BRANCH=$(git branch --show-current)
BASE_BRANCH=$(git remote show origin | awk '/HEAD branch/ {print $NF}')
CHANGED_FILES=$(git diff --name-only origin/${BASE_BRANCH}...HEAD)
git status --short
```

コミットしていない変更がある場合は`git diff --name-only HEAD`の結果も`CHANGED_FILES`に加えます。引数にPR番号がある場合は`gh pr diff <番号> --name-only`で確定します。

## Step 2: 実行済みのチェックを特定してスキップする

同じツールの二重実行を避けるため、レビュー対象リポジトリの次のファイルを確認します。

- `lefthook.yml`・`.lefthook.yml`・`.husky/`（pre-commit hookで実行されるツール）
- `.github/workflows/*.yml`（CIで実行されるツール）

pre-commit hookまたはCIで実行されているツールは、このスキルでの実行をスキップし、結果報告に「`<ツール名>`: lefthook / CIで実行済みのためスキップ」と明記します。

## Step 3: 設定ファイルからツールを検出して実行する

変更ファイルの種類とリポジトリの設定ファイルに応じて該当するCLIを実行します。ツールが見つからない場合やコマンドがエラーになった場合は、その項目をスキップして次に進みます。

各コマンドはローカルインストール（`node_modules/.bin/`）→グローバルインストール→`npx -y`（一時実行）の順に解決して実行します。`semgrep`はPythonツールのためnpxで実行できません（`brew install semgrep`等でのインストールが必要です）。

| ツール | 用途 | 実行条件 |
|---|---|---|
| `madge` | 循環参照・依存数サマリー | .ts / .tsx / .js / .jsxが含まれる場合 |
| `knip` | 未使用エクスポート検出 | .ts / .tsx / .js / .jsxが含まれる場合 |
| `semgrep` | セキュリティ静的解析 | .ts / .tsx / .js / .jsxが含まれる場合 |
| `markuplint` | アクセシビリティ静的解析 | .tsx / .jsxが含まれる場合 |
| `react-doctor` | Reactコンポーネント診断 | .tsx / .jsxが含まれる場合 |
| `npm audit` | CVE検出 | package.jsonが変更された場合 |
| `socket` | サプライチェーンリスク検出 | package.jsonが変更された場合 |
| バンドルアナライザー | バンドルサイズ | package.jsonが変更された場合 |

### 循環参照・依存数（.ts / .tsx / .js / .jsxが含まれる場合）

```bash
if [ -f node_modules/.bin/madge ]; then MADGE=node_modules/.bin/madge
elif command -v madge >/dev/null 2>&1; then MADGE=madge
else MADGE="npx -y madge@latest"; fi
CHANGED_DIRS=$(echo "$CHANGED_FILES" | xargs -I{} dirname {} | sort -u)
echo "$CHANGED_DIRS" | xargs -I{} sh -c "$MADGE --circular --ts-config tsconfig.json \"\$1\"" -- {} 2>/dev/null
echo "$CHANGED_FILES" | grep -E '\.(ts|tsx|js|jsx)$' | xargs sh -c "$MADGE --summary \"\$@\"" -- 2>/dev/null
```

### 未使用エクスポート（.ts / .tsx / .js / .jsxが含まれる場合）

```bash
if [ -f node_modules/.bin/knip ]; then KNIP=node_modules/.bin/knip
elif command -v knip >/dev/null 2>&1; then KNIP=knip
else KNIP="npx -y knip@latest"; fi
eval "$KNIP --exports" 2>/dev/null | head -30
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
if [ -f node_modules/.bin/socket ]; then SOCKET=node_modules/.bin/socket
elif command -v socket >/dev/null 2>&1; then SOCKET=socket
else SOCKET="npx -y @socketsecurity/cli@latest"; fi
eval "$SOCKET ci" 2>/dev/null | head -30
```

### バンドルサイズ（package.jsonが変更された場合）

ビルドツールを検出してバンドルアナライザーを実行します。バンドルアナライザーが設定されていない場合はスキップします。

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
if [ -f node_modules/.bin/markuplint ]; then MARKUPLINT=node_modules/.bin/markuplint
elif command -v markuplint >/dev/null 2>&1; then MARKUPLINT=markuplint
else MARKUPLINT="npx -y markuplint@latest"; fi
[ -n "$CHANGED_JSX" ] && eval "$MARKUPLINT $CHANGED_JSX" 2>/dev/null
```

### React診断（.tsx / .jsxが含まれる場合）

```bash
if [ -f node_modules/.bin/react-doctor ]; then RDOCTOR=node_modules/.bin/react-doctor
elif command -v react-doctor >/dev/null 2>&1; then RDOCTOR=react-doctor
else RDOCTOR="npx -y react-doctor@latest"; fi
eval "$RDOCTOR $CHANGED_JSX --verbose" 2>/dev/null | head -120
```

コマンドが失敗した場合はスキップします。

## Step 4: 結果を整理して出力する

全ツールの出力から指摘を抽出し、同一または実質同じ内容はひとつの項目に集約します。ツールの出力を要約するだけにとどめ、AIの判断による指摘は加えません（判断が必要なレビューはx-code-review-judgmentが担当します）。

```
## 静的解析結果

### 実行したツール
- <ツール名>: <実行 / スキップ（理由）>

### 指摘事項
- <指摘内容>
  出典: <madge / knip / semgrep / npm audit / socket / バンドルアナライザー / react-doctor / markuplint>
```

指摘が1件もない場合は「指摘なし」と報告します。
