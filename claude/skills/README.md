# Skills

Claude Codeから呼び出せるカスタムスキルの一覧です。

## Implementing（実装）

- [x-figma-extract](./x-figma-extract/SKILL.md) — Figma MCPから実装に必要なデータを取得し、プロジェクトのCSSフレームワークに合わせてトークンを引き当て、マッピングファイルに記録します。
- [x-figma-implement](./x-figma-implement/SKILL.md) — `x-figma-extract`のマッピングファイルとスクリーンショットをもとに、Figmaのデザインに合わせてコンポーネントやページを実装します。
- [x-verifying-npm-package-security](./x-verifying-npm-package-security/SKILL.md) — npmパッケージのインストール・アップデート前にCVE・サプライチェーン・メンテナンス・ライセンス・peerDepsを検証し、GO/HOLD/NO-GOを判定します。

## Reviewing（成果物の点検）

- [x-code-review-judgment](./x-code-review-judgment/SKILL.md) — AIの判断が必要なレビューを実施します。Fowlerスメル・規約・shallow module検出・テスタビリティのStandards軸と、変更の意図と実装の一致を確認するSpec軸の2軸で評価します。
- [x-code-review-static](./x-code-review-static/SKILL.md) — 静的解析ツールを決定論的に実行します。lefthookやCIで実行済みのチェックはスキップします。
- [x-code-review-git-history](./x-code-review-git-history/SKILL.md) — ホットスポット・書き換え率・Temporal Couplingを分析します。変更規模が最低ラインに満たない場合はスキップします。
- [x-test-review](./x-test-review/SKILL.md) — 既存のテストファイル（`.test.ts`／`.test.tsx`／`.spec.ts`、テストコードブロックを含む`.md`）を、テスト実装ルールに沿って見直して改善します。
- [x-japanese-reasoning-review](./x-japanese-reasoning-review/SKILL.md) — 日本語Markdown文書の主張と根拠を段落単位で洗い出し、根拠のない主張や関連の見えない根拠の扱いをユーザーに質問して、完成稿と変更一覧を提示します。ユーザーが明示的に起動したときだけ動作します。

`.md`ファイルの文章品質レビューは `claude/agents/japanese-writing-review/` のサブエージェントが担当します。`format.sh`（PostToolUse hook）から自動起動するほか、「日本語チェック」「writing-review」などの依頼でも起動できます。表記・語彙・文体の床はjapanese-writing-reviewが担い、論の構造の点検はその上にx-japanese-reasoning-reviewを重ねて使う想定です。推奨起動順はjapanese-writing-review → x-japanese-reasoning-reviewです。

## Shipping（リモートへの反映）

- [x-commit](./x-commit/SKILL.md) — Gitコミットを論理単位で分割し、人とAIにとって有用なメッセージを付けて作成します。プロジェクトの規約（commitlintなど）を遵守します。
- [x-rebasing-feature-branch](./x-rebasing-feature-branch/SKILL.md) — フィーチャーブランチをベースブランチ（main／master／developなど）にリベースし、リモートに反映するまでを1タスクとして実行します。

## Meta（スキルや計画への横断作用）

- [x-grill-me](./x-grill-me/SKILL.md) — 計画や設計を質問攻めで固めたい場合にユーザーが呼ぶ入口です。`x-grilling`を起動するだけのラッパーです。
- [x-grilling](./x-grilling/SKILL.md) — grillingのメカニクス本体です。プレーンテキストで1ラウンド最大3問を推奨回答付きで並列に提示し、意思決定ツリーのすべての分岐が解消するまで質問を繰り返します。
- [x-teach-me](./x-teach-me/SKILL.md) — ドキュメント・実装・アーキテクチャを段階的に解説し、その過程と結論をMarkdownドキュメントとして書き出します。
- [x-disprove](./x-disprove/SKILL.md) — 確定前の成果物を失敗する前提で敵対的に検証し、根拠・根拠の所在・深刻度と確度・トレードオフを添えて指摘を返します。着手直前と共有直前に必ず起動します。
