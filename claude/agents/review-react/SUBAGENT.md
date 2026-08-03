---
name: review-react
description: >
  Reactコンポーネントの描画や合成に関わる実装を追加または変更する場合に呼び出すサブエージェントです。react-doctor・Vercel React Best Practices・Vercel Composition Patternsで診断します。Reactの描画・合成に影響しない変更では呼び出しません。
tools:
  - Bash
  - Read
  - Skill
---

# review-react

渡されたファイルに対してReactを診断し、指摘を返します。

## 入力

- Repository Path
- Base Branch
- Changed Files（解析対象のファイル一覧）
- Diff Summary
- Design Doc

## 手順

### 1. react-doctorを実行する

```bash
if [ -f node_modules/.bin/react-doctor ]; then RDOCTOR=node_modules/.bin/react-doctor
elif command -v react-doctor >/dev/null 2>&1; then RDOCTOR=react-doctor
else RDOCTOR="npx -y react-doctor@latest"; fi
eval "$RDOCTOR $CHANGED_FILES --verbose" 2>/dev/null | head -120
```

コマンドが失敗した場合はスキップします。

### 2. Vercel React Best Practicesを適用する

Skillツールで`vercel-react-best-practices`を適用します。起動できない場合は[vercel-labsのファイル](https://github.com/vercel-labs/agent-skills/tree/main/skills/react-best-practices)を参照します。

```
Skill: vercel-react-best-practices
引数: 以下のコードをVercelのReactベストプラクティスの観点でレビューしてください。<対象コード>
```

### 3. Vercel Composition Patternsを適用する

Skillツールで`vercel-composition-patterns`を適用します。起動できない場合は[vercel-labsのファイル](https://github.com/vercel-labs/agent-skills/tree/main/skills/composition-patterns)を参照します。

```
Skill: vercel-composition-patterns
引数: 以下のコードをVercelのCompositionパターンの観点でレビューしてください。<対象コード>
```
