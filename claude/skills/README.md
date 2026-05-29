# Skills

Claude Codeから呼び出せるカスタムスキルの一覧です。

## Planning（着手前の計画）

- [x-planning-implementation](./x-planning-implementation/SKILL.md) — 曖昧な依頼を、別のAIコーディングエージェントが実行できる粒度の実装計画ファイルに変換します。
- [x-decompose](./x-decompose/SKILL.md) — 大きな計画や実装タスクを、依存関係順に並んだ最小単位のステップに分解します。
- [x-designing-usecases](./x-designing-usecases/SKILL.md) — 対象×インターフェイスで系統分けし、観点と状況軸を紐づけたUC表を作ります。`x-designing-testcases`の入力になります。
- [x-hotspot-refactoring](./x-hotspot-refactoring/SKILL.md) — git logのhotspot分析・循環参照・デッドコード・不安定性メトリクスを組み合わせ、リファクタリング優先候補を提案します。

## Implementing（実装）

- [x-implementing-plan](./x-implementing-plan/SKILL.md) — 計画ファイルのパスを受け取り、実装〜lint〜テスト〜コードレビュー〜計画ファイル更新〜ふりかえりまでを1セッションで実行します。
- [x-designing-testcases](./x-designing-testcases/SKILL.md) — UC表を入力にテスト計画とテストコードを生成します。3層検証（自動テスト/Agentic Verification/手動検証）を割り当てます。
- [x-figma-extract](./x-figma-extract/SKILL.md) — Figma MCPから実装に必要なデータを取得し、プロジェクトのCSSフレームワークに合わせてトークンを引き当て、マッピングファイルに記録します。
- [x-figma-implement](./x-figma-implement/SKILL.md) — `x-figma-extract`のマッピングファイルとスクリーンショットをもとに、Figmaのデザインに合わせてコンポーネントやページを実装します。
- [x-verifying-npm-package-security](./x-verifying-npm-package-security/SKILL.md) — npmパッケージのインストール・アップデート前にCVE・サプライチェーン・メンテナンス・ライセンス・peerDepsを検証し、GO/HOLD/NO-GOを判定します。

## Reviewing（成果物の点検）

- [x-thorough-code-review](./x-thorough-code-review/SKILL.md) — GitHubのPRかローカルブランチの変更をレビューします。レビュー観点の指定がなければ標準ルールで進めます。
- [x-test-review](./x-test-review/SKILL.md) — 既存のテストファイル（`.test.ts`／`.test.tsx`／`.spec.ts`、テストコードブロックを含む`.md`）を、テスト実装ルールに沿って見直して改善します。
- [x-writing-review](./x-writing-review/SKILL.md) — `.md`ファイルの文章品質を、日本語表現・構造・整形のルールに沿ってレビュー・修正します。

## Shipping（リモートへの反映）

- [x-commit](./x-commit/SKILL.md) — Gitコミットを論理単位で分割し、人とAIにとって有用なメッセージを付けて作成します。プロジェクトの規約（commitlintなど）を遵守します。
- [x-rebasing-feature-branch](./x-rebasing-feature-branch/SKILL.md) — フィーチャーブランチをベースブランチ（main／master／developなど）にリベースし、リモートに反映するまでを1タスクとして実行します。

## Meta（スキルや計画への横断作用）

- [x-grill-me](./x-grill-me/SKILL.md) — 計画や設計について、共通認識に至り意思決定ツリーのすべての分岐が解消されるまで、ユーザーを徹底的に問い詰めます。
- [x-pre-mortem](./x-pre-mortem/SKILL.md) — 計画や設計の着手前に、失敗した未来を想定して原因を逆算で洗い出し、対策を提案します。
- [x-iterate](./x-iterate/SKILL.md) — 指定したスキルを3回繰り返し適用します。レビュー・計画・実装などファイルを変更するスキルに使います。
- [x-teach-me](./x-teach-me/SKILL.md) — ドキュメント・実装・アーキテクチャを段階的に解説し、その過程と結論をMarkdownドキュメントとして書き出します。
- [x-retrospective](./x-retrospective/SKILL.md) — セッションのふりかえりをKPTA形式で行い、設定の改善提案と即時反映までを担います。
