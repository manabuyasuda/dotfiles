# Claude Code GitHub Actions 事例集

[Claude Code GitHub Actionsベストプラクティス](./claude-code-github-actions.md)の補足資料です。Claude CodeをCI・自動化（とくにGitHub Actions）で使った実運用の事例を、用途（やりたいこと）別にまとめています。すべて実際にページを開いて、実在と内容を確認しました（確認日: 2026-06-15）。計39件です。

> [!NOTE]
> 効果欄の削減率やコストは各社・各筆者の自己申告であり、第三者が検証した値ではありません。Claude Code GitHub Actionsは更新が速いため、設定の細部は各事例の公開時期に注意して読んでください。

## PR の自動レビュー

| 何をしたか | 効果・特徴 | 事例（提供元・時期） |
|---|---|---|
| GitHub Actions で PR コメントを自動化し、フォーマット修正やテストのリファクターを Claude に任せる | 公式が示す社内活用パターン | [How Anthropic teams use Claude Code（Anthropic・2025-07-24）](https://www.anthropic.com/news/how-anthropic-teams-use-claude-code) |
| Claude Code で AI PR レビューシステムを構築 | 数週間で構築（自己申告） | [CircleCI（Anthropic 顧客事例）](https://claude.com/customers/circleci) |
| PR レビュー機能を plugin（pr-review-toolkit）で専用サブエージェントに拡張 | Plugins でのカスタマイズ例 | [DELTA（Zenn・2025-12-04）](https://zenn.dev/team_delta/articles/2025-12-cc-actions) |
| 生成される PR 自動レビュー/オンデマンドの2ワークフローを読み解く | Action 内部の理解 | [chot（Zenn・2026-02-27）](https://zenn.dev/chot/articles/67b7a6c113a3ec) |
| 5つの専門レビュアーを並列起動し、PR にインラインコメント | サブエージェント並列レビュー | [GENDA（Zenn・2025-12-04）](https://zenn.dev/genda_jp/articles/70aa9a74ac1e62) |
| レビュアー不足対策に AI レビューを導入 | 1週間で83 PR・約 $0.31/レビュー（自己申告） | [dely / クラシル（Zenn・2025-08-27）](https://zenn.dev/dely_jp/articles/aa9f6cd5e05a0d) |
| Claude Code Hooks と GitHub Actions で自動 PR レビューボットを構築 | ローカル確定チェックと CI 解析の併用 | [Vikas Sah（Medium・2026-03-26）](https://engineeratheart.medium.com/build-an-autonomous-code-review-bot-with-claude-code-hooks-github-actions-in-30-minutes-038e92e59eeb) |

## Issue・コメントからの自動実装と PR 作成

| 何をしたか | 効果・特徴 | 事例（提供元・時期） |
|---|---|---|
| auto-fix ラベルで worktree 隔離環境を作り、自律修正・lint・PR 作成 | ラベル起点の自動修正 | [Solvio（Zenn・2026-03-26）](https://zenn.dev/solvio/articles/63842f1417883a) |
| Max プランで Issue コメントを起点に機能を自動実装 | Max プランでの運用例 | [クイック（Qiita・2025-07-14）](https://qiita.com/sekineck/items/330d9d41d5d1f023f90b) |
| Issue から PR を自動生成（モデル選択機能付き） | Issue から PR への自動化 | [インティメート・マージャー（Qiita・2025-12-14）](https://qiita.com/naoto714714/items/44987fd35817c63b3642) |
| Issue で `@Claude` をメンションし、隔離コンテナーで複数エージェントを並行稼働 | 複数 PR 並行開発のスケール | [Bill Prin（Medium・2025-09-08）](https://medium.com/@waprin/scaling-claude-code-with-github-actions-and-pull-requests-1dd8ce46e465) |
| Spec Kit と GitHub Actions で仕様駆動開発を実践 | Issue と自動ワークフローでアプリを構築 | [Insight Edge（2025-10-30）](https://techblog.insightedge.jp/entry/spec-kit-sdd-with-github) |

## セキュリティ・脆弱性対応

| 何をしたか | 効果・特徴 | 事例（提供元・時期） |
|---|---|---|
| GitHub Action で全 PR をセキュリティスキャンし、重大度付きでコメント | 700以上のリポジトリに展開（自己申告） | [Deriv（2026-03-31）](https://derivai.substack.com/p/automated-security-code-reviews-claude-code-github-actions) |
| Claude Code GitHub Action のプロンプトインジェクション脆弱性を分析 | 導入時のセキュリティ検討材料 | [Microsoft Security Blog（2026-06-05）](https://www.microsoft.com/en-us/security/blog/2026/06/05/securing-ci-cd-in-agentic-world-claude-code-github-action-case/) |
| 設定中に自分でプロンプトインジェクションを起こした体験談 | セキュリティ上の教訓 | [I accidentally prompt-injected myself…（Hacker News）](https://news.ycombinator.com/item?id=44527916) |

## テスト・CI/CD 連携・自己修復

| 何をしたか | 効果・特徴 | 事例（提供元・時期） |
|---|---|---|
| Claude Code で修正し、GitLab CI/CD が自動検証する3ワークフローを提示 | CI/CD 連携の型 | [GitLab（公式・2026-05-06）](https://about.gitlab.com/blog/claude-code-and-gitlab/) |
| Agentic Pipelines が Claude を対応し、テスト修復・ドキュメント更新等を自動化 | Bitbucket での公式対応 | [Atlassian / Bitbucket（公式・2026-05-19）](https://www.atlassian.com/blog/bitbucket/agentic-pipelines-now-supports-claude-code) |
| テスト失敗を検知・分類し、修正提案や PR 作成を行う GitHub Action | self-healing テストの試み | [Show HN: Claude Code Watchdog（Hacker News）](https://news.ycombinator.com/item?id=44502049) |
| CLI でテストを自動化し、Datadog / Sentry 連携でインシデント対応を自動化 | 調査時間を最大80%短縮（自己申告） | [Ramp（Anthropic 顧客事例）](https://claude.com/customers/ramp) |

## 依存更新・保守・品質の自動化

| 何をしたか | 効果・特徴 | 事例（提供元・時期） |
|---|---|---|
| ルールベースのフィルターと Claude レビューで、Dependabot の依存更新 PR を自動マージ | 定型 PR の自動マージ | [サイバーエージェント（2025-12-09）](https://developers.cyberagent.co.jp/blog/archives/60598/) |
| ランナーイメージのフォーク保守を日次 CI で自動化、破壊的変更でドラフト PR | 保守自動化の事例 | [Depot（2025-07-16）](https://depot.dev/blog/how-we-automated-github-actions-runner-updates-with-claude) |
| headless モードを CI に組み込み、定型保守の PR を自動オープン、ドキュメント更新も自動化 | CI への組み込み例 | [Doctolib（Anthropic 顧客事例）](https://claude.com/customers/doctolib) |
| dupl の重複検出と Claude Code Action と Devin で、リファクター PR を自動生成 | コード品質改善の仕組み | [SMat / potix2（Speaker Deck・2025-06-26）](https://speakerdeck.com/potix2/improve-code-quality-metrics-with-claude-code-action) |

## 定期実行・トリアージ・継続タスク

| 何をしたか | 効果・特徴 | 事例（提供元・時期） |
|---|---|---|
| GitHub webhook routine がリポジトリイベントで Claude を自動起動 | スケジュール/イベント駆動の自動化 | [Introducing routines in Claude Code（Anthropic・2026-04-14）](https://claude.com/blog/introducing-routines-in-claude-code) |
| `claude-issue-triage.yml` で issue を自動トリアージしラベル付与（WIF 認証） | 公式の issue トリアージ運用 | [anthropics/claude-code（公式）](https://github.com/anthropics/claude-code/blob/main/.github/workflows/claude-issue-triage.yml) |
| Claude Code Actions と cron で継続リサーチを自動化し、結果を蓄積して差分抽出 | 継続リサーチの自動化 | [DeNA（2025-07-30）](https://engineering.dena.com/blog/2025/07/claude-code-actions-iteration-research/) |
| Skill と GitHub Actions で問い合わせ調査を横断的に自動化 | 調査時間を平均70%削減・1〜2時間→約10分（自己申告） | [ZOZO（2026-06-01）](https://techblog.zozo.com/entry/cs-inquiry-ai-automation) |
| 週次 GitHub Action で全 CLAUDE.md をファクトチェック更新、CI 監視エージェントを運用 | 13プラグイン・100以上のスキル（自己申告） | [Intercom（2026-03-19）](https://ideas.fin.ai/p/how-we-use-claude-code-today-at-intercom) |

## 導入・設定・運用ノウハウ

| 何をしたか | 効果・特徴 | 事例（提供元・時期） |
|---|---|---|
| 非対話モード `claude -p` を CI・pre-commit・スクリプトへ統合する方法を解説 | headless 運用の基礎 | [Best practices for Claude Code（Anthropic Engineering）](https://www.anthropic.com/engineering/claude-code-best-practices) |
| Claude Code で README 索引を自動更新する GitHub Actions ワークフローを構築 | 約7分の動画で実演 | [Simon Willison（2025-07-01）](https://simonwillison.net/2025/Jul/1/claude-code-github-actions/) |
| Claude Code を GitHub Actions で動かす設定を解説 | 高速ランナーでコスト・時間を削減 | [Depot（2025-05-23）](https://depot.dev/blog/claude-code-in-github-actions) |
| print モードで Claude Code を CI/CD で無人実行する方法を網羅 | 認証・コスト・定期ジョブの解説 | [Hidekazu Konishi（2026-06-07）](https://hidekazu-konishi.com/entry/claude_code_cicd_and_headless_automation.html) |
| `claude-code-action@v1` をメンション/自動レビュー/定期実行の3パターンで解説 | ガードレール重視のレシピ | [backgroundclaude.com（2026-04-10）](https://backgroundclaude.com/blog/github-actions) |
| Pro / Max 加入者が OAuth でサブスク枠の GitHub Action を設定 | サブスク枠での手順 | [coderSloth（Medium・2026-05-03）](https://codersloth.medium.com/how-to-install-claude-as-a-github-action-on-a-pro-or-max-subscription-a8de7dc18c32) |
| `@claude` メンションの AI レビュー・実装をセットアップ（Max プラン認証を含む） | 導入ガイド | [アクセンチュア有志（Zenn・2025-05）](https://zenn.dev/acntechjp/articles/3f361da473eac8) |
| Claude Code Action で AI レビューを組み込むデモと設計方針を解説 | 入門スライド | [GLOBIS / technuma（Speaker Deck・2025-12-04）](https://speakerdeck.com/technuma/claude-code-action-for-beginners) |
| レビュー用プロンプトを GitHub Issue で管理し、CI 時に読み込む | プロンプトの外部管理 | [ナレッジワーク（Zenn・2026-03-06）](https://zenn.dev/knowledgework/articles/claude-code-action-issue-prompt) |
| `claude.yml` で `@claude` メンションを起点に git・gh CLI・CI 読み取りを許可 | 公式リポジトリの実ワークフロー | [anthropics/anthropic-sdk-python（公式 SDK）](https://github.com/anthropics/anthropic-sdk-python/blob/main/.github/workflows/claude.yml) |
| Code / Security / Design Review の3ワークフローを GitHub Actions と slash command で提供 | 再利用できるワークフロー集 | [OneRedOak/claude-code-workflows（OSS）](https://github.com/OneRedOak/claude-code-workflows) |
