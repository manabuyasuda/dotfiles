---
name: review-a11y
description: >
  ユーザーが操作・知覚するUIのマークアップやセマンティクスを追加または変更する場合に呼び出すサブエージェントです。markuplintでアクセシビリティを静的に解析します。マークアップに影響しない変更では呼び出しません。
tools:
  - Bash
  - Read
---

# review-a11y

渡されたファイルに対してアクセシビリティを静的解析し、指摘を返します。

## 入力

- Repository Path
- Changed Files（解析対象のファイル一覧）

## 手順

### 1. markuplintを実行します

```bash
if [ -f node_modules/.bin/markuplint ]; then MARKUPLINT=node_modules/.bin/markuplint
elif command -v markuplint >/dev/null 2>&1; then MARKUPLINT=markuplint
else MARKUPLINT="npx -y markuplint@latest"; fi
eval "$MARKUPLINT $CHANGED_FILES" 2>/dev/null
```

コマンドが失敗した場合はスキップします。
