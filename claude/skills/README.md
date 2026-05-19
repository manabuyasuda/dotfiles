# Skills

Claude Codeから呼び出せるカスタムスキルの一覧です。

## Planning（着手前の計画）

- [planning-implementation](./planning-implementation/SKILL.md) — 曖昧な依頼を、別のAIコーディングエージェントが実行できる粒度の実装計画ファイルに変換します。
- [decompose](./decompose/SKILL.md) — 大きな計画や実装タスクを、依存関係順に並んだ最小単位のステップに分解します。
- [designing-usecases](./designing-usecases/SKILL.md) — 対象×インターフェイスで系統分けし、観点と状況軸を紐づけたUC表を作ります。`designing-testcases`の入力になります。
- [hotspot-refactoring](./hotspot-refactoring/SKILL.md) — git logのhotspot分析・循環参照・デッドコード・不安定性メトリクスを組み合わせ、リファクタリング優先候補を提案します。

## Implementing（実装）

- [implementing-plan](./implementing-plan/SKILL.md) — 計画ファイルのパスを受け取り、実装〜lint〜テスト〜コードレビュー〜計画ファイル更新〜ふりかえりまでを1セッションで実行します。
- [designing-testcases](./designing-testcases/SKILL.md) — UC表を入力にテスト計画とテストコードを生成します。3層検証（自動テスト/Agentic Verification/手動検証）を割り当てます。
- [figma-extract](./figma-extract/SKILL.md) — Figma MCPから実装に必要なデータを取得し、プロジェクトのCSSフレームワークに合わせてトークンを引き当て、マッピングファイルに記録します。
- [figma-implement](./figma-implement/SKILL.md) — `figma-extract`のマッピングファイルとスクリーンショットをもとに、Figmaのデザインに合わせてコンポーネントやページを実装します。

## Reviewing（成果物の点検）

- [code-review](./code-review/SKILL.md) — GitHubのPRかローカルブランチの変更をレビューします。レビュー観点の指定がなければ標準ルールで進めます。
- [test-review](./test-review/SKILL.md) — 既存のテストファイル（`.test.ts`／`.test.tsx`／`.spec.ts`、テストコードブロックを含む`.md`）を、テスト実装ルールに沿って見直して改善します。
- [writing-review](./writing-review/SKILL.md) — `.md`ファイルの文章品質を、日本語表現・構造・整形のルールに沿ってレビュー・修正します。

## Shipping（リモートへの反映）

- [commit](./commit/SKILL.md) — Gitコミットを論理単位で分割し、人とAIにとって有用なメッセージを付けて作成します。プロジェクトの規約（commitlintなど）を遵守します。
- [rebasing-feature-branch](./rebasing-feature-branch/SKILL.md) — フィーチャーブランチをベースブランチ（main／master／developなど）にリベースし、リモートに反映するまでを1タスクとして実行します。

## Meta（スキルや計画への横断作用）

- [grill-me](./grill-me/SKILL.md) — 計画や設計について、共通認識に至り意思決定ツリーのすべての分岐が解消されるまで、ユーザーを徹底的に問い詰めます。
- [pre-mortem](./pre-mortem/SKILL.md) — 計画や設計の着手前に、失敗した未来を想定して原因を逆算で洗い出し、対策を提案します。
- [iterate](./iterate/SKILL.md) — 指定したスキルを3回繰り返し適用します。レビュー・計画・実装などファイルを変更するスキルに使います。
- [teach-me](./teach-me/SKILL.md) — ドキュメント・実装・アーキテクチャを段階的に解説し、その過程と結論をMarkdownドキュメントとして書き出します。
- [retrospective](./retrospective/SKILL.md) — セッションのふりかえりをKPTA形式で行い、設定の改善提案と即時反映までを担います。
