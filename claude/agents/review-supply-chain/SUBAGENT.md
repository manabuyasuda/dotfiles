---
name: review-supply-chain
description: >
  依存パッケージの追加・更新・削除など、依存関係の構成を変える場合に呼び出すサブエージェントです。npm audit・socket・バンドルアナライザーでサプライチェーン・CVE・バンドルサイズを検証します。依存関係の構成に影響しない変更では呼び出しません。
tools:
  - Bash
  - Read
---

# review-supply-chain

サプライチェーンを検証し、指摘を返します。

## 入力

- Repository Path
- Changed Files

## 手順

### 1. npm auditを実行する

```bash
npm audit --audit-level=moderate 2>/dev/null | head -30
```

### 2. socketを実行する

```bash
if [ -f node_modules/.bin/socket ]; then SOCKET=node_modules/.bin/socket
elif command -v socket >/dev/null 2>&1; then SOCKET=socket
else SOCKET="npx -y @socketsecurity/cli@latest"; fi
eval "$SOCKET ci" 2>/dev/null | head -30
```

### 3. バンドルサイズを確認する

ビルドツールを検出してバンドルアナライザーを実行します。設定されていない場合はスキップします。

```bash
if grep -q '"next"' package.json 2>/dev/null; then
  BUILD_TOOL="nextjs"
elif grep -q '"vite"' package.json 2>/dev/null; then
  BUILD_TOOL="vite"
else
  BUILD_TOOL="unknown"
fi

case "$BUILD_TOOL" in
  nextjs)
    if grep -q '"@next/bundle-analyzer"' package.json 2>/dev/null; then
      ANALYZE=true npm run build 2>/dev/null | tail -30
    else
      echo "bundle-analyzerが設定されていない"
    fi
    ;;
  vite)
    if grep -q '"rollup-plugin-visualizer"' package.json 2>/dev/null; then
      npm run build 2>/dev/null | tail -20
    else
      echo "bundle-analyzerが設定されていない"
    fi
    ;;
esac
```
