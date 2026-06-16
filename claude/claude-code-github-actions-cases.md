# Claude Code GitHub Actions 事例集

[Claude Code GitHub Actionsベストプラクティス](./claude-code-github-actions.md)の補足資料です。Claude CodeをCI・自動化（とくにGitHub Actions）で使った実運用の事例を、用途（やりたいこと）別にまとめています。各事例の目的・取り組み・アウトプット/アウトカムを、出典記事の記述に基づいて整理しています。計39件です（確認日: 2026-06-15）。

> [!NOTE]
> アウトカム欄の数値は各社・各筆者の自己申告で、第三者が検証した値ではありません。成果が数値で報告されていない手順解説・検証記事は、その旨を明記しています。Claude Code GitHub Actionsは更新が速いため、設定の細部は各事例の公開時期に注意して読んでください。

## PR の自動レビュー

| 目的（なぜ） | 取り組み（何をしたか） | アウトプット・アウトカム | 事例（提供元・時期） |
|---|---|---|---|
| テスト最適化・ビルド修正などの保守作業のバックログを解消したい | Claude Agent SDKで自律エージェント「Chunk」を構築し、自然言語タスクから検証済みPRを出すクローズドループにした | テスト実行時間が平均75%削減（最大97%）、ある顧客で解析時間が14時間→18分、PR化率が2倍超 | [CircleCI（Anthropic顧客事例）](https://claude.com/customers/circleci) |
| レビュワー減少でレビュー時間が増え、見落としも発生していた | PR自動レビューを導入し、指摘をnits/should/imo/mustで分類して日本語コメント化した | 1週間で83件・PR当たり約$0.31（月約$102）、必須レビュワーを2人→1人に削減 | [dely / クラシル（Zenn・2025-08-27）](https://zenn.dev/dely_jp/articles/aa9f6cd5e05a0d) |
| 長文一括レビューはコードとの対応付けが難しく、見落としやPRの縦長化が起きていた | `/review-pr`で5つの専門サブエージェント（品質/性能/テスト/ドキュメント/セキュリティ）を並列実行しインラインコメント化した | 見落としが減り、人間は設計・仕様整合などの高度なレビューに集中（定量値なし） | [GENDA（Zenn・2025-12-04）](https://zenn.dev/genda_jp/articles/70aa9a74ac1e62) |
| 反復作業を自動化し開発ワークフローを加速したい（社内各チームの活用例） | GitHub ActionsでPRコメント・フォーマット修正・テストのリファクターを自動化した | 事例紹介（時間短縮の言及はあるが体系的な測定値はなし） | [How Anthropic teams use Claude Code（Anthropic・2025-07-24）](https://www.anthropic.com/news/how-anthropic-teams-use-claude-code) |
| 導入済みGHAの内部構造を把握しPluginでカスタマイズしたい | `claude-code-review.yml`に`plugin_marketplaces`/`plugins`を追加しpr-review-toolkitを導入した | 手順解説（成果報告なし） | [DELTA（Zenn・2025-12-04）](https://zenn.dev/team_delta/articles/2025-12-cc-actions) |
| 紹介されたGHAを実際に動かして中身を理解したい | `/install-github-app`で2ワークフロー（@claude / Code Review）を設定し生成yamlを分析した | 手順解説（動作確認のみ・成果報告なし） | [chot（Zenn・2026-02-27）](https://zenn.dev/chot/articles/67b7a6c113a3ec) |
| AI生成コードの欠陥率や速度品質ギャップに対処したい | Claude Code Hooks（危険操作のブロック）とGitHub Actionsの意味解析を2層で組み合わせ自律レビューBotを構築した | 手順解説（成果報告なし。記事中の改善率は外部ベンチマークの引用） | [Vikas Sah（Medium・2026-03-26）](https://engineeratheart.medium.com/build-an-autonomous-code-review-bot-with-claude-code-hooks-github-actions-in-30-minutes-038e92e59eeb) |

## Issue・コメントからの自動実装と PR 作成

| 目的（なぜ） | 取り組み（何をしたか） | アウトプット・アウトカム | 事例（提供元・時期） |
|---|---|---|---|
| Issue起票から着手まで時間がかかり、夜間のバグ報告が翌朝まで放置されていた | 「auto-fix」ラベルでgit worktreeの隔離環境を作り、修正〜lint〜PR作成まで自動化した | 手順解説（成果報告なし） | [Solvio（Zenn・2026-03-26）](https://zenn.dev/solvio/articles/63842f1417883a) |
| MaxプランでGHAが使えるようになったため試したい | `/install-github-app`を設定し、Next.jsアプリでIssueコメントを起点に機能を自動実装した | 体験レポート（動作確認のみ・成果報告なし） | [クイック（Qiita・2025-07-14）](https://qiita.com/sekineck/items/330d9d41d5d1f023f90b) |
| IssueからPRを自動生成する仕組みを作りたい | MCPツールでIssue取得・ブランチ作成・PR作成を行うワークフローを構築した | 手順解説（成果報告なし） | [インティメート・マージャー（Qiita・2025-12-14）](https://qiita.com/naoto714714/items/44987fd35817c63b3642) |
| AI支援開発をスケールさせたい（lint修正やレビュー指摘が時間を消費） | Issueで@Claudeをメンションし、隔離されたGHA環境で複数機能を並行作業させた | 探索記事（定量結果なし） | [Bill Prin（Medium・2025-09-08）](https://medium.com/@waprin/scaling-claude-code-with-github-actions-and-pull-requests-1dd8ce46e465) |
| ドキュメントと実装の同期が人手依存で、AI活用プロセスが監査できなかった | Spec Kitの`/specify`〜`/implement`とClaude Code GHAで仕様駆動開発を実践した（オセロアプリ） | 手順解説（成果報告なし） | [Insight Edge（2025-10-30）](https://techblog.insightedge.jp/entry/spec-kit-sdd-with-github) |

## セキュリティ・脆弱性対応

| 目的（なぜ） | 取り組み（何をしたか） | アウトプット・アウトカム | 事例（提供元・時期） |
|---|---|---|---|
| 700超リポジトリ・週100超PRの規模で、手動セキュリティレビューが遅く品質にばらつきがあった | GHAで全PRを自動スキャンし、CWE分類と修正例付きでコメント、@claudeで追加対応もできるようにした | 告知（初週にXSSやデバッグモード有効化を検出した事例の記載。全体の効果数値はなし） | [Deriv（2026-03-31）](https://derivai.substack.com/p/automated-security-code-reviews-claude-code-github-actions) |
| Claude Code GitHub Actionで、信頼できないGitHubコンテンツが機密情報を露出し得るリスクを検証したい | リバースシェルを狙うテストワークフローを構築し、Readツールで`/proc/self/environ`からAPIキーを取得できることを実証した | 脆弱性をAnthropicへ報告し、v2.1.128で緩和（セキュリティ分析） | [Microsoft Security Blog（2026-06-05）](https://www.microsoft.com/en-us/security/blog/2026/06/05/securing-ci-cd-in-agentic-world-claude-code-github-action-case/) |
| GHA利用中に起きた偶発的なプロンプトインジェクションを共有したい | 設定中に自分自身をプロンプトインジェクションした体験を投稿した（リンク先はXのスレッド） | 注意喚起（スレッド本文は取得できず、定量データなし） | [I accidentally prompt-injected myself…（Hacker News）](https://news.ycombinator.com/item?id=44527916) |

## テスト・CI/CD 連携・自己修復

| 目的（なぜ） | 取り組み（何をしたか） | アウトプット・アウトカム | 事例（提供元・時期） |
|---|---|---|---|
| 開発速度を強みに、開発者の生産性を高めたい | テスト失敗の自律的な解析・修正・再実行、MCP連携のログ集約によるインシデント対応、ドキュメント自動生成を行った | 30日で100万行超のAI提案コード、週次アクティブ利用50%、インシデント調査時間を最大80%削減 | [Ramp（Anthropic顧客事例）](https://claude.com/customers/ramp) |
| ノイズの多いCI失敗やフレイキーテストが本当の問題を隠していた | テスト失敗を分析・重大度分類し、過去20回の実行から慢性失敗と偶発フレイクを区別、確信時にPRを自動作成するGitHub Actionを提供した | 分析1失敗あたり約$0.20（投稿者の申告） | [Show HN: Claude Code Watchdog（Hacker News）](https://news.ycombinator.com/item?id=44502049) |
| コーディング自動化が進むほどバグ滞留・パイプライン失敗・脆弱性蓄積が追いつかない | Claude CodeとGitLab Duo Agent Platformの連携を3パターン提示した（CI/CD検証・GitLab MCP・MRレビュー） | 告知/解説（成果報告なし） | [GitLab（公式・2026-05-06）](https://about.gitlab.com/blog/claude-code-and-gitlab/) |
| 開発チームが低価値・反復的な作業に時間を費やしている | Bitbucket Pipelinesに「Agentic Pipelines」を追加し、Claudeをプロバイダー統合した（不安定テストの自動修復など） | 告知（open beta・成果報告なし） | [Atlassian / Bitbucket（公式・2026-05-19）](https://www.atlassian.com/blog/bitbucket/agentic-pipelines-now-supports-claude-code) |

## 依存更新・保守・品質の自動化

| 目的（なぜ） | 取り組み（何をしたか） | アウトプット・アウトカム | 事例（提供元・時期） |
|---|---|---|---|
| 速いリリースと信頼性を両立したい（オンボーディング数週間、PRレビュー数時間〜数日がボトルネック） | 全開発チームに展開し、CIにヘッドレスモードで保守用PRの自動生成とドキュメント自動更新を組み込み、回帰テスト基盤を全面置換した | 回帰テスト基盤の移行が数週間→数時間、オンボーディングが数週間→数日、PRレビュー待ちが即座に | [Doctolib（Anthropic顧客事例）](https://claude.com/customers/doctolib) |
| ABEMA広告配信は依存パッケージが多く、Dependabot PRの安全性判断を人手で行い完全自動化できていなかった | patch/minorのみ・信頼できる開発元・CI通過＋AIで破壊的変更や実使用への影響を判定する5条件をAuto Mergeと組み合わせた | 更新事例でPR作成からマージまで約2分、ルール外パッケージのスキップも実証（集計値なし） | [サイバーエージェント（2025-12-09）](https://developers.cyberagent.co.jp/blog/archives/60598/) |
| フォークしたRunnerイメージの手動更新に毎週数時間を消費していた | 日次CIでClaudeがARM64パッチ再生成・上流変更の分析・衝突解消・破壊的変更の検出を行いドラフトPR化した | 毎週数時間を要した作業がバックグラウンドで自動実行されるようになった（定量指標は「数時間」のみ） | [Depot（2025-07-16）](https://depot.dev/blog/how-we-automated-github-actions-runner-updates-with-claude) |
| AI生成の速度が人間のレビュー速度を上回り、構造的な重複の品質改善が必要だった | 毎朝dupl（重複検出）でIssue自動作成→Devinで分割→Claude Code ActionでPR作成のループを構築した | 1日あたりIssue3件→PR1〜2件→マージ1件。Claude単体では難しく人間・他ツールの補助が必須と結論 | [SMat / potix2（Speaker Deck・2025-06-26）](https://speakerdeck.com/potix2/improve-code-quality-metrics-with-claude-code-action) |

## 定期実行・トリアージ・継続タスク

| 目的（なぜ） | 取り組み（何をしたか） | アウトプット・アウトカム | 事例（提供元・時期） |
|---|---|---|---|
| CSからの技術調査が1件1〜2時間かかり、習熟度差で専任に負荷が集中していた | 調査手順をClaude Code Skill化し、複数リポジトリを横断する7ステップの自動調査フローを実装した | 調査リードタイムを平均70%削減（一次回答が約10分） | [ZOZO（2026-06-01）](https://techblog.zozo.com/entry/cs-inquiry-ai-automation) |
| Deep Researchがセッション単位でしか記憶を持たず、過去調査との差分抽出が難しかった | Claude Code Actions＋cronで定期実行し、結果をリポジトリに蓄積する継続リサーチを構築した | 著者が「まだ実用段階に至っていない」と明記（ハルシネーション対策などが残課題） | [DeNA（2025-07-30）](https://engineering.dena.com/blog/2025/07/claude-code-actions-iteration-research/) |
| cron・インフラ・MCPサーバなどの追加ツールを自前管理する負担を減らしたい | Claude Codeにroutinesを追加し、スケジュール型・API型・GitHub Webhook型のトリガーを提供した | 告知/解説（成果報告なし） | [Introducing routines in Claude Code（Anthropic・2026-04-14）](https://claude.com/blog/introducing-routines-in-claude-code) |
| GitHub issueをClaudeで自動トリアージしたい | `claude-code-action@v1`で`/triage-issue`によりラベルを自動編集する公式ワークフローを提供した（WIF認証） | 提供物（設定ファイル・成果記載なし） | [anthropics/claude-code（公式）](https://github.com/anthropics/claude-code/blob/main/.github/workflows/claude-issue-triage.yml) |
| Claudeを社内のフルスタックなエンジニアリング基盤にしたい | 13プラグイン・100超スキルを配布し、週次GHAで全CLAUDE.mdをファクトチェック更新、CI監視のフックなどを運用した | 告知/解説（測定可能な改善値なし） | [Intercom（2026-03-19）](https://ideas.fin.ai/p/how-we-use-claude-code-today-at-intercom) |

## 導入・設定・運用ノウハウ

| 目的（なぜ） | 取り組み（何をしたか） | アウトプット・アウトカム | 事例（提供元・時期） |
|---|---|---|---|
| ローカル限定のClaude CodeをGHAで動かし、バックグラウンド自動化基盤にしたい | 公式GitHub Appの導入とワークフロー設定を解説し、高速ランナーへの切替を案内した | 5分セッションのコスト比較（GitHubホスト$0.04 / Depot $0.02 / 小型Depot $0.01） | [Depot（2025-05-23）](https://depot.dev/blog/claude-code-in-github-actions) |
| 対話型Claude CodeをCI/CDで無人実行する際の権限・コスト・監査のリスクに対処したい | print mode・3プロバイダー認証・ガードレール・コスト制御・可観測性・スケジューリングを網羅的に解説した | 解説（成果報告なし） | [Hidekazu Konishi（2026-06-07）](https://hidekazu-konishi.com/entry/claude_code_cicd_and_headless_automation.html) |
| プロンプト修正のたびにpush・PRマージが必要でコストが高く、複数チームで考慮漏れが起きていた | プロンプトをGitHub Issueに記述しCIから読む仕組みにし、Issue編集での更新やラベルでの動的取得を実装した | 実装例・ベストプラクティスの共有（成果報告なし） | [ナレッジワーク（Zenn・2026-03-06）](https://zenn.dev/knowledgework/articles/claude-code-action-issue-prompt) |
| AIレビュー導入時の「欲しいレビューが来ない」課題と、確率的挙動のブレを抑えたい | 単一責任（AIは1タスク）・確定処理はスクリプト担当・知識ベースの継続改善という設計方針を提示した | 設計方針の解説（成果報告なし） | [GLOBIS / technuma（Speaker Deck・2025-12-04）](https://speakerdeck.com/technuma/claude-code-action-for-beginners) |
| 自律的なエージェントコーディングの学習コストを下げたい | 非対話モード（`claude -p`）でのCI組込み・fan-out並列・CLAUDE.md/権限/フック/スキル設定を解説した | 解説（成果報告なし） | [Best practices for Claude Code（Anthropic Engineering）](https://www.anthropic.com/engineering/claude-code-best-practices) |
| GHAでのClaude Code実行が煩雑でエラーが起きやすかった | `claude-code-action@v1`を@claudeメンション/自動PRレビュー/スケジュールの3パターンで解説した | 手順解説（成果報告なし） | [backgroundclaude.com（2026-04-10）](https://backgroundclaude.com/blog/github-actions) |
| Pro/Max契約者がOAuthトークンで既存枠を使う導入手順を示したい | GitHub App導入・OAuthトークン生成・Secrets設定・ワークフロー作成を段階的に解説した | 手順解説（成果報告なし） | [coderSloth（Medium・2026-05-03）](https://codersloth.medium.com/how-to-install-claude-as-a-github-action-on-a-pro-or-max-subscription-a8de7dc18c32) |
| PR/Issue向けにClaude Codeで質問回答・コード変更を行わせる環境を構築したい | GitHub App・APIキー・権限・claude.yml・Max向けトークンの5手順を解説した | 手順解説（成果報告なし） | [アクセンチュア有志（Zenn・2025-05）](https://zenn.dev/acntechjp/articles/3f361da473eac8) |
| README索引を自動更新する機能を追加したい | Claude CodeでGitHub Actionsワークフローを構築する様子を約7分の動画で実演した | 手順解説（成果報告なし） | [Simon Willison（2025-07-01）](https://simonwillison.net/2025/Jul/1/claude-code-github-actions/) |
| issue/PRで@claudeメンションに応答させたい | `claude-code-action@v1`を使い、許可ツール（git・gh CLI）と権限（contents/PR/issues write・actions read）を定義する公式ワークフローを提供した | 提供物（設定ファイル・成果記載なし） | [anthropics/anthropic-sdk-python（公式SDK）](https://github.com/anthropics/anthropic-sdk-python/blob/main/.github/workflows/claude.yml) |
| ルーチン作業を自動化し、チームが戦略思考やアーキテクチャ整合に集中できるようにしたい | コードレビュー・セキュリティレビュー（OWASP Top 10）・デザインレビュー（Playwright MCP）の3ワークフローを提供した | 提供物（成果記載なし） | [OneRedOak/claude-code-workflows（OSS）](https://github.com/OneRedOak/claude-code-workflows) |
