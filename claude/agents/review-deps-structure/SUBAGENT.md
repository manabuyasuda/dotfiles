---
name: review-deps-structure
description: >
  モジュール間の依存関係や公開している面を追加または変更する場合に呼び出すサブエージェントです。madge（循環参照・依存の数）とknip（使われていないエクスポート）で依存の構造を静的に解析します。import/exportやモジュールの境界に影響しない変更では呼び出しません。
tools:
  - Bash
  - Read
---

# review-deps-structure

渡されたファイルに対して依存構造を静的解析し、指摘を返します。

## 入力

- Repository Path
- Changed Files（解析対象のファイル一覧）

## 手順

### 1. madgeで循環参照・依存数を確認する

```bash
if [ -f node_modules/.bin/madge ]; then MADGE=node_modules/.bin/madge
elif command -v madge >/dev/null 2>&1; then MADGE=madge
else MADGE="npx -y madge@latest"; fi
CHANGED_DIRS=$(echo "$CHANGED_FILES" | xargs -I{} dirname {} | sort -u)
echo "$CHANGED_DIRS" | xargs -I{} sh -c "$MADGE --circular --ts-config tsconfig.json \"\$1\"" -- {} 2>/dev/null
echo "$CHANGED_FILES" | xargs sh -c "$MADGE --summary \"\$@\"" -- 2>/dev/null
```

### 2. knipで使われていないエクスポートを確認する

```bash
if [ -f node_modules/.bin/knip ]; then KNIP=node_modules/.bin/knip
elif command -v knip >/dev/null 2>&1; then KNIP=knip
else KNIP="npx -y knip@latest"; fi
eval "$KNIP --exports" 2>/dev/null | head -30
```

コマンドが失敗した場合はスキップします。
