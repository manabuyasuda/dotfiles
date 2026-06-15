# Claude Code GitHub Actions ベストプラクティス

公式ドキュメントと一般的なGitHub Actionsの運用知見、および筆者自身の検証をもとにまとめた設計指針です。

> [!NOTE]
> 確認日: 2026-06-15。Claude Code GitHub Actions は更新が速いため、利用時は末尾の「参考リンク」にある一次情報を再確認してください。実運用の事例は別ファイル [Claude Code GitHub Actions 事例集](./claude-code-github-actions-cases.md) にまとめています。

## 全体設計の前提

### Action の選択

| Action | 実装方式 | 主な認証 | CLAUDE.md / スキル | `@claude` 対話 |
|---|---|---|---|---|
| `anthropics/claude-code-action` | Claude CLI をサブプロセスとして起動（v1 が標準） | API Key / OAuth / Bedrock / Vertex AI | 読み込みあり | 組み込み（自動で検知・返信） |
| `anthropics/claude-code-base-action` | Claude Code を実行する薄いラッパー | API Key / OAuth / Bedrock / Vertex AI / Foundry | 読み込みあり | なし（`prompt` を自分で渡す） |

> `claude-code-base-action` は `claude-code-action` 内の `base-action` を自動ミラーしたものです。新規プロジェクトは `claude-code-action@v1` が標準で、メンション対話や進捗コメントが要らない独自の自動化や、trust boundary を厳密に管理したい場合に base-action を選びます。どちらも有効な選択肢で、base-action が非推奨というわけではありません。

**両 Action の本質的な差は「GitHub イベント文脈の自動付与」と「`@claude` 対話の有無」であって、CLAUDE.md を読み込むかどうかではありません。**

- CLAUDE.md・スキル（`.claude/`）: **どちらの Action も**、チェックアウト済みのリポジトリにあれば自動で読み込みます。base-actionのREADMEにも「Claude reads project-level configuration (`.claude/`, `CLAUDE.md`, `.mcp.json`, etc.) from the working directory」と明記されています。「base-actionはCLAUDE.mdを読まずクリーンなプロンプトになる」は誤りです。
- `claude-code-action`: Issue / PRの本文やコメントといったGitHubイベントの文脈を自動でプロンプトに付与し、`@claude` メンションを検知して返信・進捗コメントまで行います。ローカルでの作業に近い挙動です。
- `claude-code-base-action`: GitHub文脈の自動付与やメンション検知はなく、`prompt` / `prompt_file` で渡した内容だけを実行します。文脈を自分で制御できるぶん、CI自動化を細かく組みたい場合に向きます。

この差は課金形態（従量課金 / サブスク）とは無関係で、Actionの種類と設定に由来します。`@claude` 対話はサブスク専用ではなく、従量課金の `ANTHROPIC_API_KEY` でも動作します。どのイベントで起動するか（`@claude` メンション / ラベル / PRイベント）は `on:` と権限・トリガー設定次第です。

### Action 選択と設定の対応

`claude-code-action` では多くの設定をCLI引数（`claude_args`）としてまとめて渡します。`claude-code-base-action` も `claude_args` を受け付けます。一方、`track_progress`（進捗コメント）と `use_sticky_comment`（コメントの集約）は **`claude-code-action` v1 専用の input** で、base-actionにはありません。

---

## 最小構成（まず動かす）

各論の前に、コピーして動かせる最小のワークフローを示します。`@claude` メンションに反応して、Issue / PRでのコメント返信・実装・PR作成までこなす、もっとも基本的な構成です。本番ではここに権限の最小化・スコープ限定・タイムアウトなどを足します。

```yaml
name: Claude
on:
  issue_comment:
    types: [created]
  pull_request_review_comment:
    types: [created]
  issues:
    types: [opened, assigned]

permissions: {}

jobs:
  claude:
    # `@claude` を含むイベントだけに反応する
    if: |
      (github.event_name == 'issue_comment' && contains(github.event.comment.body, '@claude')) ||
      (github.event_name == 'pull_request_review_comment' && contains(github.event.comment.body, '@claude')) ||
      (github.event_name == 'issues' && contains(github.event.issue.body, '@claude'))
    runs-on: ubuntu-latest
    timeout-minutes: 30
    permissions:
      contents: write
      pull-requests: write
      issues: write
      id-token: write
    steps:
      - uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd # v6.0.2
        with:
          fetch-depth: 1
      - uses: anthropics/claude-code-action@787c5a0ce96a9a6cfb050ea0c8f4c05f2447c251 # v1.0.133
        with:
          anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
          claude_args: |
            --model claude-sonnet-4-6
            --max-turns 20
```

事前準備は2つです。Anthropic Consoleで発行したAPIキーを `ANTHROPIC_API_KEY` としてGitHub Secretsに登録し、ClaudeのGitHub App（`/install-github-app`）をリポジトリに入れておきます。サブスク枠で動かす場合は `anthropic_api_key` を `claude_code_oauth_token` に置き換えます（認証設計を参照）。

---

## トリガーと実行モード

### メンション対話モードと automation モード

claude-code-actionは `prompt` 入力の有無で動作が変わります。`prompt` を省略するとメンション待ちの対話モードになり、`@claude` を検知して応答します。`prompt` を渡すとautomationモードになり、メンションを待たずにその内容を実行します。定期実行やラベル起点の自動化ではautomationモードを使います。

### 起動語を変える

`@claude` 以外を起動語にしたい場合は `trigger_phrase` を指定します。モデルの出し分け（例: `@opus`）などと組み合わせられます。

```yaml
- uses: anthropics/claude-code-action@...
  with:
    trigger_phrase: "@opus"
```

### 定期実行（cron）

夜間サマリや依存監査など、イベントに依らない定期タスクは `schedule` トリガーで起動します（cronはUTC基準）。`prompt` を渡してautomationモードで実行します。

```yaml
on:
  schedule:
    - cron: "0 9 * * *"   # 毎日 09:00 UTC
```

---

## タイムアウトと実行上限

### 時間とターン数の両方で上限を設ける

ターン数だけで打ち切ると、タスクの複雑さに関係なく止まり、複雑な実装タスクで未完了になりやすいです。一方で上限がないと、暴走時にジョブが長時間ぶら下がります。claude-code-actionでは、ジョブの `timeout-minutes`（実時間の上限）と `claude_args` の `--max-turns` / `--max-budget-usd`（作業量と費用の上限）を組み合わせて制御します。

> [!NOTE]
> base-action には Claude 実行専用の `timeout_minutes` という input がありますが、claude-code-action（v1）にはありません。claude-code-action では、実行時間はジョブの `timeout-minutes` で、作業量と費用は `claude_args` で抑えます。コスト管理が主目的なら、API 利用額で打ち切る `--max-budget-usd`（print モードのオプション）の方が `--max-turns` より意図に合います。

```yaml
jobs:
  claude:
    timeout-minutes: 45          # ジョブ全体の実時間上限（暴走時の保険）
    steps:
      - uses: anthropics/claude-code-action@...
        with:
          anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
          claude_args: |
            --max-turns 40         # 作業量（ターン数）の上限
            --max-budget-usd 5.00  # API 利用額の上限
```

### 用途別の目安

数値は運用しながら調整する出発点です。

| 用途 | ジョブ timeout-minutes | --max-turns |
|---|---|---|
| コメント反応・レビュー | 30 分 | 15〜25 |
| Issue 実装・Fix | 45 分 | 40 |
| 複雑な分析・複数フェーズ処理 | 60 分 | 60 |

---

## コストとレート制限

`@claude` をすべてのPR・Issueで起動すると、従量課金では費用が積み上がります。トリガーを絞り、1実行の上限を決めるのが基本です。

- トリガーを限定する: 特定ラベル・特定パス・`@claude` メンションのみなど、`on:` と `if:` で起動条件を狭める。
- 1実行の上限を決める: `claude_args` の `--max-turns`（ターン数）と `--max-budget-usd`（API利用額。printモード）で打ち切る。
- 多重起動を抑える: concurrencyで同一Issue / PRの並行実行を止める（「Concurrency制御」を参照）。

費用感はPRの規模とモデルで大きく変わります。事例ではAIレビューを約 $0.31/レビューで回したという報告があります（事例集のdely）。大きなPRほどトークン消費が増えて高くなるため、自分のリポジトリで小さく試して実測してから広げてください。いずれも各筆者の自己申告値です。

レート制限にも注意します。APIは利用が集中すると429（Too Many Requests）を返すことがあり、サブスク枠（OAuthトークン）には5時間・7日の使用量上限があります。CIで上限に当たると実行が失敗するため、トリガーの限定とリトライ設計で当たりにくくしておきます。

実行時間と費用は、`runs-on` を高速なランナー（Depotなど）に替えても下げられます（事例集のDepot）。

---

## セキュリティ・権限チェック

### プロンプトインジェクション対策（ラベルトリガー必須）

ラベルトリガーを使う場合、ラベルを付けた人（write権限あり）とIssue本文を書いた人が別人になり得る。**Issue 作成者の権限を実行時に API で確認**する。

```yaml
- name: Check issue author permission
  id: check-permission
  uses: actions/github-script@...
  with:
    script: |
      const issueAuthor = context.payload.issue?.user?.login || '';
      // 信頼済みボット（GitHub App 等）はホワイトリストで許可
      const trustedBots = ['your-github-app-bot[bot]'];
      let allowed = trustedBots.includes(issueAuthor);
      if (!allowed) {
        try {
          const { data } = await github.rest.repos.getCollaboratorPermissionLevel({
            owner: context.repo.owner,
            repo: context.repo.repo,
            username: issueAuthor,
          });
          allowed = ['admin', 'write'].includes(data.permission);
        } catch (error) {
          core.warning(`Permission check failed: ${error.message}`);
        }
      }
      core.setOutput('allowed', String(allowed));

- name: Run Claude
  if: steps.check-permission.outputs.allowed == 'true'
  uses: ...
```

**ホワイトリスト設計の理由**: Issue本文がGitHub Appやtrusted botによって自動生成される場合、権限APIには登録されていないことがある。ボット名を明示的に許可しておくことで意図せず弾かれるのを防ぐ。

### スコープ限定

PRに含まれるファイル変更が特定のディレクトリ内に収まっているかを確認してから実行すると、関係のない変更に反応するリスクを下げられる。

```yaml
- name: Check PR scope
  id: check-scope
  uses: actions/github-script@...
  with:
    script: |
      const files = await github.paginate(github.rest.pulls.listFiles, {
        owner: context.repo.owner,
        repo: context.repo.repo,
        pull_number: context.payload.pull_request.number,
      });
      const inScope = files.some(f => f.filename.startsWith('systems/your-product/'));
      core.setOutput('in_scope', String(inScope));
```

### フォーク PR と信頼できない入力を前提にする

Issue・PR・コメントの本文は誰でも書ける信頼できない入力で、そのまま特権的な操作に渡すとプロンプトインジェクションの経路になります。次を前提に組みます。

- 信頼できない入力の扱いは、組み込みの緩和を持つ `claude-code-action` に任せます。素の `claude-code-base-action` を外部入力に対して使いません。
- フォークからのPRでは `pull_request_target` を避けます。baseリポジトリの権限とsecretsで動くため、外部の変更コードと組み合わせると危険です。外部コントリビューターのPRで動かす場合は、前述の権限チェックで実行を絞ります。
- 信頼できない本文をシェルに直接展開しません。`run:` で `${{ github.event.comment.body }}` のように補間せず、環境変数（`env:`）経由で渡します。

### ボット・自分のコメントでループさせない

Claude自身の投稿や他のボットのコメントに反応すると、無限ループやムダな起動になります。コメント起点のジョブでは `if:` でボットを除外します（Issue起票など他のイベントでも、対応する作者で同様に除外します）。

```yaml
jobs:
  claude:
    if: >-
      github.event.comment.user.type != 'Bot' &&
      contains(github.event.comment.body, '@claude')
```

### permissions の最小化

ジョブ側で必要なものだけを明示する。トップレベルで `permissions: {}` を設定してデフォルト権限を封じ、ジョブごとに必要最小限を付与する。

```yaml
permissions: {}  # トップレベルで全権限を無効化

jobs:
  claude:
    permissions:
      contents: write
      pull-requests: write
      issues: write
      id-token: write  # OIDC 認証を使う場合
      actions: read    # Claude に CI 結果（ワークフローログ）を読ませる場合
```

---

## ツール許可の粒度

### 広い `Bash` 単体許可は避ける

`Bash` だけを許可するとファイル読み書きができない一方でシェル操作は何でも通る、という歪な状態になる。

**実装タスクに必要な最小セット**:

```yaml
allowed_tools: >-
  Bash(gh issue view:*),Bash(gh issue comment:*),
  Bash(gh pr view:*),Bash(gh pr list:*),Bash(gh pr create:*),Bash(gh pr comment:*),
  Bash(gh run list:*),Bash(gh api:*),
  Bash(git log:*),Bash(git diff:*),Bash(git status:*),
  Bash(git add:*),Bash(git commit:*),Bash(git push:*),Bash(git checkout:*),
  Glob,Grep,Read,Edit,Write,MultiEdit
```

**読み取り・分析のみに絞る場合**:

```yaml
allowed_tools: >-
  Bash(gh pr view:*),Bash(gh pr diff:*),Bash(gh pr list:*),
  Bash(gh issue view:*),Bash(gh run view:*),
  Bash(git log:*),Bash(git diff:*),Bash(git show:*),
  Glob,Grep,Read
```

### MCP サーバーを使う場合の許可

MCPツールは `mcp__<server>__<tool>` 形式で個別に許可できる。

```yaml
allowed_tools: >-
  ...,
  mcp__github__create_issue,
  mcp__github__add_issue_comment,
  mcp__context7__resolve-library-id,
  mcp__context7__get-library-docs
```

### ブラックリストと権限モード

許可リスト（allowlist）の逆に、特定の操作だけを禁止したい場合は `claude_args` の `--disallowedTools` を使います。

```yaml
claude_args: --disallowedTools "Bash(git push:*)"
```

CIでの権限の扱いは `--permission-mode` で決められます。変更させず提案だけ出させるなら `plan`、許可済みの編集を自動適用するなら `acceptEdits` を指定します。

```yaml
claude_args: --permission-mode plan
```

---

## Concurrency 制御

### 多重起動の抑制

同一Issue / PRへの並行実行はリソースのムダ遣いになり、競合状態を引き起こすこともある。

```yaml
concurrency:
  group: claude-${{ github.event.issue.number || github.event.pull_request.number }}
  cancel-in-progress: false  # 実行中は止めない（途中状態を防ぐ）
```

**`cancel-in-progress` の選び方**:

| 値 | 適切な場面 |
|---|---|
| `false` | 実装タスク・Fix（順序重要、中途半端な状態を防ぐ） |
| `true` | コメント反応・分析系（最新の実行だけ処理すれば十分） |

**ワークフローレベルではなくジョブレベルに設定する理由**: ワークフローレベルだと `if` 条件でスキップされたときもキャンセルが発動してしまう。

---

## 認証設計

認証方式は、一般的な利用頻度の高い順に次のとおりです。いずれも両Actionで利用できます（Microsoft Foundryを使う `use_foundry` はbase-actionのみ）。

1. `ANTHROPIC_API_KEY`（Anthropic API直接・従量課金）
2. `CLAUDE_CODE_OAUTH_TOKEN`（Claudeサブスク枠）
3. Workload Identity Federation（OIDC・静的キー不要）
4. Amazon Bedrock
5. Google Vertex AI

以下の例は標準である `claude-code-action` で示します。

### 1. API Key（もっとも一般的・公式の既定）

もっともシンプルで、公式セットアップの既定です。Anthropic Consoleで発行した `ANTHROPIC_API_KEY` をGitHub Secretsに保存します。

```yaml
- uses: anthropics/claude-code-action@...
  with:
    anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
```

従量課金で、利用量に応じてコストが発生します。

### 2. OAuth トークン（サブスク枠・非推奨）

`claude setup-token`（発行したトークンは約1年有効）で取得した `CLAUDE_CODE_OAUTH_TOKEN` を使うと、Claudeのサブスクリプション枠で動かせます。

```yaml
- uses: anthropics/claude-code-action@...
  with:
    claude_code_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
```

ただし**公式の既定は `ANTHROPIC_API_KEY`** です。サブスク（Consumer向け）トークンをCIのような自動実行に使うことは利用規約上のグレーゾーンとされます。筆者の個人検証では動作しましたが、推奨はしません。本番運用ではAPI Keyか、後述のクラウドプロバイダー認証を選びます。

### 3. Workload Identity Federation（静的キーを置かない）

GitHub ActionsのOIDCトークンを交換して認証する方式です。ダウンロード可能なキーをSecretsへ置かずに済むため、後述のBedrock / Vertexを含めて推奨されます。

### 4. Bedrock / Vertex AI を使う場合

**Bedrock（OIDC）**を使う場合は次のように設定します。

```yaml
- name: Configure AWS Credentials
  uses: aws-actions/configure-aws-credentials@...
  with:
    role-to-assume: ${{ secrets.AWS_ROLE_TO_ASSUME }}
    aws-region: us-west-2

- uses: anthropics/claude-code-action@...
  with:
    use_bedrock: true
    model: us.anthropic.claude-sonnet-4-6  # リージョンプレフィックス必須
```

**Vertex AI（Workload Identity Federation）**を使う場合は次のように設定します。

```yaml
- name: Authenticate to Google Cloud
  uses: google-github-actions/auth@...
  with:
    workload_identity_provider: ${{ secrets.GCP_WORKLOAD_IDENTITY_PROVIDER }}
    service_account: ${{ secrets.GCP_SERVICE_ACCOUNT }}

- uses: anthropics/claude-code-action@...
  with:
    use_vertex: true
    model: claude-opus-4-8
  env:
    ANTHROPIC_VERTEX_PROJECT_ID: ${{ steps.auth.outputs.project_id }}
    CLOUD_ML_REGION: us-east5
```

ダウンロード可能なサービスアカウントキーを持たずに済むよう、Bedrock / VertexともOIDC（Workload Identity Federation）での認証を推奨します。

### GitHub App Token を使う理由

デフォルトの `GITHUB_TOKEN` は `actions/checkout` が事前に使っているため、Claudeが作るコミットやPRがCIをトリガーできないケースがある。**GitHub App Token を使うと CI が正常にトリガーされる。**

```yaml
- name: Create GitHub App Token
  uses: actions/create-github-app-token@...
  id: app-token
  with:
    app-id: ${{ secrets.APP_ID }}
    private-key: ${{ secrets.APP_PRIVATE_KEY }}

- uses: anthropics/claude-code-action@...
  env:
    GH_TOKEN: ${{ steps.app-token.outputs.token }}
```

---

## チェックアウト最適化

### monorepo では sparse-checkout を使う

関係のないコードをチェックアウトするとインストール・ビルドが遅くなり、コンテキストにも余計なものが混入する。

```yaml
- uses: actions/checkout@...
  with:
    token: ${{ steps.app-token.outputs.token }}
    persist-credentials: false
    fetch-depth: 1
    sparse-checkout: |
      systems/your-product
      .github/workflows
    sparse-checkout-cone-mode: false  # ディレクトリ構造を完全保持（CI に必須）
```

**`sparse-checkout-cone-mode: false` が必要な理由**: cone modeはディレクトリ単位の高速マッチングだが、`systems/your-product` 以外の設定ファイルが除外されてしまうケースがある。非cone modeにすることでglobパターンが正確に機能する。

### `persist-credentials: false` の推奨

デフォルトではcheckout後にgit credentialとして `GITHUB_TOKEN` が残る。Claudeがpush等を行う場合、意図しないトークンで操作されるリスクを避けるため `false` にして、明示的に `GH_TOKEN` 環境変数で渡す方が安全。

---

## 失敗時フィードバック

### `continue-on-error` と失敗コメントをセットで入れる

Claudeの実行ステップで `continue-on-error: true` にした場合、`failure()` だけでは失敗を検知できない。**`steps.<id>.outcome == 'failure'` も条件に加える**。

```yaml
- name: Run Claude
  id: claude
  uses: anthropics/claude-code-action@...
  continue-on-error: true

- name: Comment on failure
  if: failure() || steps.claude.outcome == 'failure'
  env:
    GH_TOKEN: ${{ steps.app-token.outputs.token }}
  run: |
    gh issue comment "${{ github.event.issue.number }}" \
      --repo "${{ github.repository }}" \
      --body "❌ Claude の実行に失敗しました。
    
    詳細は[ワークフローログ](${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }})をご確認ください。"
```

---

## 実行環境の伝達

### 環境情報をプロンプトに明示する

CI上ではsparse-checkoutでCLAUDE.mdを含めていなかったり、hooksが動かなかったりする場合がある。重要な前提はプロンプト内で明示的に伝えると一貫した動作が得られる。

```yaml
prompt: |
  GitHub Actions のランナー上で動作している。

  <environment>
  - 起動時のディレクトリ: systems/your-product
  - GitHub CLI (`gh`) は認証済みで利用可能
  - リポジトリ: ${{ github.repository }}
  - Issue 番号: ${{ github.event.issue.number }}
  </environment>

  <task>
  1. AGENTS.md を読んでガイドラインを確認
  2. gh issue view ${{ github.event.issue.number }} で Issue 内容を確認
  3. 実装して PR を作成する
  </task>

  <rules>
  - テストは実行しない（CI に任せる）
  - Issue に記載された内容のみを実装する
  - 過度なリファクタリングは行わない
  </rules>
```

### システムプロンプトで規約を注入する

プロジェクト規約や応答言語を一貫させたい場合は、`claude_args` の `--append-system-prompt`（既存に追記）または `--system-prompt`（置換）で渡します。CLAUDE.mdを置きにくい構成でも規約を効かせられます。

```yaml
claude_args: --append-system-prompt "コミットメッセージは日本語にする。テストは実行しない。"
```

### ワーキングディレクトリを明示する

```yaml
env:
  CLAUDE_WORKING_DIR: ${{ github.workspace }}/systems/your-product
```

---

## 発展的パターン

### モデルの動的選択

コメント内のキーワードでモデルを切り替えることで、通常は軽量モデルを使いながら必要なときだけ高性能モデルを使える。

```yaml
- name: Determine model
  id: model
  env:
    COMMENT: ${{ github.event.comment.body }}   # 信頼できない本文は env 経由で渡す
  run: |
    if echo "$COMMENT" | grep -qi "opus"; then
      echo "model=claude-opus-4-8" >> "$GITHUB_OUTPUT"
    else
      echo "model=claude-sonnet-4-6" >> "$GITHUB_OUTPUT"
    fi

- uses: anthropics/claude-code-action@...
  with:
    claude_args: --model ${{ steps.model.outputs.model }}
```

### 進捗コメントの集約

Claudeが途中経過を複数コメントで投稿するとPRが散らかる。sticky comment（同じコメントを更新し続ける）で集約する。`track_progress` / `use_sticky_comment` は **`claude-code-action` v1 専用**のinputで、base-actionにはない。

```yaml
- uses: anthropics/claude-code-action@...
  with:
    track_progress: true       # PR/Issue でタグモードの進捗コメントを出す
    use_sticky_comment: true   # 1つのコメントに集約
```

### 実行前の Acknowledge

依存インストール等で時間がかかる前に「受け付けた」コメントを先に投稿することで、ユーザーが応答を待っていることへの確認ができる。

```yaml
- name: Acknowledge invocation
  run: |
    gh pr comment "$PR_NUMBER" \
      --body "🤖 実行を開始しました。完了までしばらくお待ちください。"
  env:
    GH_TOKEN: ${{ steps.app-token.outputs.token }}
    PR_NUMBER: ${{ github.event.pull_request.number }}

- name: Install dependencies
  run: pnpm install --frozen-lockfile

- name: Run Claude
  uses: ...
```

### Action バージョンを commit hash で固定する

タグ（`@v1`）はミュータブルで上書きされる可能性がある。**commit hash で固定することで予期しない変更を防ぐ。**

```yaml
# Bad
uses: anthropics/claude-code-action@v1

# Good
uses: anthropics/claude-code-action@787c5a0ce96a9a6cfb050ea0c8f4c05f2447c251 # v1.0.133
```

---

## 参考リンク

確認日（2026-06-15）時点で到達を確認した出典です。実運用の事例は別ファイル [Claude Code GitHub Actions 事例集](./claude-code-github-actions-cases.md) を参照してください。

### 一次情報（公式）

- Claude Code GitHub Actionsドキュメント — https://code.claude.com/docs/en/github-actions
- 認証方式 — https://code.claude.com/docs/en/authentication
- CLIリファレンス（`--max-turns` / `--max-budget-usd` など）— https://code.claude.com/docs/en/cli-reference
- `anthropics/claude-code-action`（`action.yml` / `docs/`）— https://github.com/anthropics/claude-code-action
- `anthropics/claude-code-base-action` — https://github.com/anthropics/claude-code-base-action
- Best practices for Claude Code — https://www.anthropic.com/engineering/claude-code-best-practices
- `actions/checkout`（`persist-credentials` など）— https://github.com/actions/checkout
- GitHub Docs: ワークフローのトリガー（`GITHUB_TOKEN` による再トリガーの制限）— https://docs.github.com/actions/using-workflows/triggering-a-workflow

### 非公式・第三者

- Securing CI/CD in an agentic world: Claude Code GitHub action case（Microsoft Security Blog, 2026-06-05）— https://www.microsoft.com/en-us/security/blog/2026/06/05/securing-ci-cd-in-agentic-world-claude-code-github-action-case/
- その他の実運用記事（各社の一次情報・コミュニティ記事）は上記「事例集」にまとめています。

---

## まとめ：設定チェックリスト

### 必須

- [ ] ジョブに `timeout-minutes` を設定している
- [ ] `claude_args` で `--max-turns`（必要なら `--max-budget-usd`）の上限を設けている
- [ ] `permissions` をジョブレベルで最小化している
- [ ] 実行に必要なツールを用途に合わせて明示している（`Bash` 単体ではない）
- [ ] 失敗時にIssue / PRへフィードバックするステップがある
- [ ] `continue-on-error: true` の場合、`steps.<id>.outcome == 'failure'` も条件に加えている
- [ ] APIキーやシークレットをGitHub Secrets経由で渡している
- [ ] 信頼できない本文（Issue / PR / コメント）を `run:` に直接展開せず `env:` 経由で渡している
- [ ] フォークPRで `pull_request_target` を避け、外部コントリビューターの実行を絞っている
- [ ] ボット・自分のコメントに反応しないよう `if:` で除外している

### ラベルトリガーを使う場合

- [ ] Issue作成者の権限チェックを入れている
- [ ] trusted botのホワイトリストを設定している
- [ ] concurrencyを設定して多重起動を抑制している

### monorepo の場合

- [ ] sparse-checkoutで必要なディレクトリだけ取得している
- [ ] `sparse-checkout-cone-mode: false` を設定している

### 推奨

- [ ] GitHub App Tokenを使い、Claudeのコミット・PRがCIをトリガーできるようにしている
- [ ] Actionのバージョンをcommit hashで固定している
- [ ] プロンプトで環境情報（リポジトリ・ブランチ・ワーキングディレクトリ）を明示している
- [ ] 定期タスクは `schedule`(cron) ＋ `prompt`（automationモード）で起動している（該当する場合）
- [ ] CI結果を読ませる場合は `actions: read` を付与している
