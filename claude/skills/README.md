# Skills

Claude Codeから呼び出せるカスタムスキルの一覧です。

## Planning（着手前の計画）

- [x-decompose](./x-decompose/SKILL.md) — 大きな計画や実装タスクを、依存関係順に並んだ最小単位のステップに分解します。

## Implementing（実装）

- [x-figma-extract](./x-figma-extract/SKILL.md) — Figma MCPから実装に必要なデータを取得し、プロジェクトのCSSフレームワークに合わせてトークンを引き当て、マッピングファイルに記録します。
- [x-figma-implement](./x-figma-implement/SKILL.md) — `x-figma-extract`のマッピングファイルとスクリーンショットをもとに、Figmaのデザインに合わせてコンポーネントやページを実装します。
- [x-verifying-npm-package-security](./x-verifying-npm-package-security/SKILL.md) — npmパッケージのインストール・アップデート前にCVE・サプライチェーン・メンテナンス・ライセンス・peerDepsを検証し、GO/HOLD/NO-GOを判定します。

## Reviewing（成果物の点検）

- [x-thorough-code-review](./x-thorough-code-review/SKILL.md) — GitHubのPRかローカルブランチの変更をレビューします。レビュー観点の指定がなければ標準ルールで進めます。
- [x-test-review](./x-test-review/SKILL.md) — 既存のテストファイル（`.test.ts`／`.test.tsx`／`.spec.ts`、テストコードブロックを含む`.md`）を、テスト実装ルールに沿って見直して改善します。

`.md`ファイルの文章品質レビューは `claude/agents/japanese-writing-review/` のサブエージェントが担当します。`format.sh`（PostToolUse hook）から自動起動するほか、「日本語チェック」「writing-review」などの依頼でも起動できます。

## Shipping（リモートへの反映）

- [x-commit](./x-commit/SKILL.md) — Gitコミットを論理単位で分割し、人とAIにとって有用なメッセージを付けて作成します。プロジェクトの規約（commitlintなど）を遵守します。
- [x-rebasing-feature-branch](./x-rebasing-feature-branch/SKILL.md) — フィーチャーブランチをベースブランチ（main／master／developなど）にリベースし、リモートに反映するまでを1タスクとして実行します。

## Meta（スキルや計画への横断作用）

- [x-grill-me](./x-grill-me/SKILL.md) — 計画や設計について、共通認識に至り意思決定ツリーのすべての分岐が解消されるまで、ユーザーを徹底的に問い詰めます。
- [x-pre-mortem](./x-pre-mortem/SKILL.md) — 計画や設計の着手前に、失敗した未来を想定して原因を逆算で洗い出し、対策を提案します。
- [x-teach-me](./x-teach-me/SKILL.md) — ドキュメント・実装・アーキテクチャを段階的に解説し、その過程と結論をMarkdownドキュメントとして書き出します。
