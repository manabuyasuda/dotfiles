# AIエージェントCLIの差分

Claude Code・Cursor CLI・Codex CLIの3つで、設定の書き方と挙動が変わる箇所をまとめます。

変更手順そのものは`README.md`の「AIエージェントの共有設定」にあります。この文書は差分だけを扱います。

## 前提

この文書を単独で読むために必要な用語です。

| 用語 | 意味 |
|---|---|
| 3つのCLI | Claude Code（`claude`）、Cursor CLI（`cursor-agent`）、Codex CLI（`codex`） |
| 情報源と生成物 | 設定は1か所だけに書き、各CLI向けのファイルはスクリプトで作ります。編集するのは生成物ではなく情報源です |
| 反映 | dotfiles内のファイルをホームディレクトリへ届けることです。方式は3つあります（2節） |
| hook | ツール実行の前後にCLIが呼び出す外部スクリプトです。本体は`claude/hooks/`に1つだけ置きます |
| 判定 | hookが返す3種類の結果です。`deny`は実行を止め、`ask`はユーザーへ確認し、出力なしはそのまま通します |
| ツール層 | CLI本体が持つ許可・拒否リストです。実際のパスとツール引数で判定します |
| シェル層 | `claude/hooks/pre-tool-use/bash-guard.sh`です。コマンドの文字列しか見えません |

## 根拠の区分

CLIの挙動についての記載には、根拠を2つのどちらかで示します。

| 記号 | 意味 | 扱い方 |
|---|---|---|
| 公式 | CLIの公式ドキュメントに書かれている仕様です。出典と確認日を併記します | 仕様として扱えます |
| 実測 | 実際にCLIを動かして確認した挙動です。確認日を併記します | 再現した事実であり、仕様の保証ではありません。CLIの更新で変わる前提で扱います |

公式と実測が食い違う箇所は、両方を並べて書きます。文書として動いているのは実測のほうです。

このリポジトリ自身の設定（どのファイルをどこへ反映するか、どのタグをどう変換するか）には根拠を付けません。設定そのものが事実であり、該当ファイルを読めば確認できます。ファイルの一覧は13節にあります。

出典の一覧です。確認日は2026-09-03です。

| CLI | 出典 |
|---|---|
| Claude Code | <https://code.claude.com/docs/en/hooks>、<https://code.claude.com/docs/en/settings> |
| Cursor | <https://cursor.com/docs/hooks> |
| Codex | <https://developers.openai.com/codex/config-reference>、<https://developers.openai.com/codex/hooks> |

## 1. 差分の一覧

| 観点 | Claude Code | Cursor CLI | Codex CLI | 根拠 |
|---|---|---|---|---|
| 設定ファイルの形式 | JSON | JSONとMarkdown（`.mdc`） | TOML | 公式 |
| 反映の方式 | シンボリックリンク | 生成とマージ | マージ | このリポジトリの設定 |
| 共有設定のうち届く範囲 | すべて | `permissions`とstatusLineだけ | hookとグローバル指示だけ | このリポジトリの設定 |
| 許可・拒否リスト | `settings.json`の`permissions` | `cli-config.json`の`permissions` | 存在しません | 実測2026-08-31 |
| 読み取りの経路 | ツール（`Read`／`Glob`）とシェル | ツールとシェル | シェルのみ | 実測2026-08-31 |
| hookの`deny` | 実行を止めます | 実行を止めます | 実行を止めます | 実測2026-08-31 |
| hookの`ask` | 通常の許可判定へ戻します | ダイアログを出さず拒否として扱います | 無視してそのまま実行します | 公式／実測2026-08-21／2026-08-31 |
| hookの信頼確認 | 不要 | 不要 | TUIの`/hooks`でtrustするまで実行されません | 実測2026-08-31 |
| 本体の導入 | `setup.sh`とは別に公式インストーラーで入れます | Homebrew経由 | `setup.sh`の対象外で、`codex login`が別途必要です | このリポジトリの設定 |

共有設定をそのまま使うと想定と食い違うのは、Codexの5項目です。許可・拒否リスト、読み取りの経路、`ask`の扱い、hookの信頼確認、本体の導入がこれにあたります。

## 2. 設定の反映方式が3つある

同じ設定でも、CLIごとに届け方が変わります。

| 方式 | 代表例 | 選ぶ条件 |
|---|---|---|
| シンボリックリンク | `claude/CLAUDE.md`、`claude/settings.json`、`claude/hooks/`、`claude/skills/`、`claude/agents/`、`cursor/hooks.json`、`codex/hooks.json` | CLIが読む形式のまま置けます |
| 生成 | `cursor/rules/global-instructions.mdc`、`codex/agents/*.toml`、`claude/settings.json`の`permissions.deny`、`cursor/cli-permissions.json` | CLIごとに形式が違います |
| マージ | `~/.codex/config.toml`、`~/.cursor/cli-config.json` | CLI自身が同じファイルへ書き込みます |

### シンボリックリンクにできない理由

| ファイル | 理由 |
|---|---|
| `cursor/rules/global-instructions.mdc` | Cursorは`description`と`alwaysApply`のfrontmatterを要求します。`CLAUDE.md`にはありません |
| `codex/agents/*.toml` | CodexのサブエージェントはTOML形式です。他の2つはMarkdownです |
| `~/.codex/config.toml` | Codexが`[projects.*]`のtrust_levelと`[hooks.state.*]`のtrusted_hashを同じファイルへ書きます |
| `~/.cursor/cli-config.json` | セッション中のユーザーの承認をCursorが同じファイルへ書きます |

後ろ2つを上書きすると、trust状態と承認履歴が消えます。そのためマージにします。

反映の方式はこのリポジトリの設定です（`setup.sh`、`scripts/merge-codex-config.sh`、`scripts/merge-cursor-cli-config.sh`）。Cursorが`.mdc`にfrontmatterを要求する点と、CodexとCursorがそれぞれの設定ファイルへ自身で書き込む点は公式です。

### 生成物のずれを止める仕組み

生成スクリプトの実行を忘れると、CLIごとに設定がずれます。lefthookの`pre-commit`で`permissions-drift`・`cursor-permissions-drift`・`cursor-rules-drift`が検出し、GitHub Actionsの`permissions-test`でも検査します。

## 3. 共有設定のうち、他のCLIへ届く範囲

`claude/settings.json`はClaude Codeの設定ファイルであり、大半の項目は他の2つへ届きません。

| 項目 | Claude Code | Cursor CLI | Codex CLI |
|---|---|---|---|
| `permissions.allow` / `permissions.deny` | そのまま読みます | 記法を変換して`cli-config.json`へ反映します | 届きません。hookのシェル層で代替します |
| `permissions.defaultMode` | 読みます | 届きません | 届きません |
| `env` | 自動で読みます | hookのアダプターが明示的に読み込みます | hookのラッパが明示的に読み込みます |
| `model` | 読みます | dotfilesの管理対象外です | `codex/config.toml`の`model`で別に指定します |
| `statusLine` | 読みます | `cursor/cli-statusline.json`で別に指定します | `config.toml`の`[tui] status_line`で別に指定します |
| `language` / `outputStyle` / `effortLevel` | 読みます | 相当する設定がありません | `model_verbosity`と`model_reasoning_summary`が近い設定です |
| `enabledPlugins` / `autoMode` / `theme` | 読みます | 相当する設定がありません | 相当する設定がありません |

`env`の扱いが分かりにくい箇所です。Claude CodeはCLI本体が環境変数として展開しますが、他の2つは展開しません。hookが同じ値を使うため、`cursor/hooks/lib/cursor-io.sh`の`cursor_io_load_settings_env`が`settings.json`から読み込みます。Codexのラッパも同じ関数を呼びます。

### statusLineは3つとも別物

| CLI | 指定するもの | 備考 |
|---|---|---|
| Claude Code | `claude/statusline.sh`（スクリプト） | — |
| Cursor CLI | `cursor/statusline.sh`（スクリプト） | CLIでのみ表示されます。IDEのAgentでは表示されません |
| Codex CLI | `[tui] status_line`（表示項目の名前のリスト） | スクリプトを指定できません |

Codexだけは項目名を並べる形式のため、スクリプトを共有できません。TUIの`/statusline`で変更した内容はCodexが`~/.codex/config.toml`へ直接書き込むため、dotfilesへ取り込む場合は手でコピーします。

各CLIが読む設定キーは公式です。どの値を入れるかはこのリポジトリの設定です（`claude/settings.json`、`codex/config.toml`、`cursor/cli-statusline.json`）。TUIの`/statusline`が`~/.codex/config.toml`へ直接書き込む点は実測2026-08-31で確認しました。

## 4. permissionsの記法が違う

`scripts/sync-cursor-cli-permissions.sh`が変換します。

| Claude Code | Cursor CLI |
|---|---|
| `Bash(...)` | `Shell(...)` |
| `Edit(...)` | `Write(...)` |
| `mcp__<サーバー>__<ツール>` | `Mcp(<サーバー>:<ツール>)` |
| `Read(...)` / `Glob(...)` / `Write(...)` | そのまま |

Codexには対応する仕組みがありません（6節）。

Cursorの記法（`Shell()`・`Write()`・`Mcp()`）は公式です。変換の実装はこのリポジトリの設定です（`scripts/sync-cursor-cli-permissions.sh`）。

## 5. hookの`ask`の扱いがCLIごとに違う

hookが返す`ask`は、3つのCLIで別々の結果になります。

| CLI | 公式の仕様 | 実測した挙動 |
|---|---|---|
| Claude Code | 通常の許可フローへ委ねます。判定を返さないのと同じ扱いです | 設定した許可モードに従い、承認ダイアログが出ます |
| Cursor CLI | 応答形式に`ask`が定義されています | ダイアログを出しません。`Rejected: <メッセージ>`としてエージェントへ返します。ユーザーが承認する手段がありません（2026-08-21、`explore/cursor-cli-hook-double-execution.md`） |
| Codex CLI | 記載を確認できていません | 判定を無視してコマンドを実行します（2026-08-31、`plan/codex-ask-decision-check.md`） |

### なぜ`ask`が「判定を返さないのと同じ」になるのか

`permissionDecision`は、通常の許可判定を上書きするための出口です。3つの値のうち、上書きするのは2つだけです。

| 値 | 動き |
|---|---|
| `allow` | 通常の判定を飛ばして実行します |
| `deny` | 通常の判定を飛ばして止めます |
| `ask` | 上書きせず、通常の判定へ戻します |

hookが何も返さなければ通常の判定が走ります。`ask`はそこへ戻すだけなので、結果が一致します。`ask`は「ユーザーへ確認せよ」という命令ではなく、「hookは判断しない」という表明です。

差が出るのは、通常の判定が承認なしで通す操作のときだけです。`permissions.allow`に一致する操作や、承認を省略する起動オプションの下では、`ask`を返してもダイアログは出ません。元から確認が要る操作なら`ask`でもダイアログが出るため、見た目では区別がつきません。

確実に止めたい操作へ`ask`を使うことはできません。`deny`を返す必要があります。

CursorとCodexは、公式の仕様と実測した挙動が食い違います。この文書と`bash-guard.sh`は実測のほうに合わせています。

### Codexへの対応

`codex/hooks/wrap/pre-tool-use.sh`が、理由文の先頭タグを見て`ask`を`deny`へ変換します。変換するのは2種類だけです。

| タグ | 例 | Codexでの扱い | 理由 |
|---|---|---|---|
| `[DESTRUCTIVE]` | `rm`、`git reset --hard`、`git push --force` | denyへ変換します | 取り消せないため |
| `[SECRET_PATH]` | ホーム直下の認証情報ファイルへの一致 | denyへ変換します | 確認しないまま読まれると実害が出るため |
| `[SECRET_NAME]` | どこにでも現れ得るファイル名への一致 | 変換の対象外です | 大半が無害な検索であり、denyにするとCodexで恒久的に実行できなくなるため |
| NETWORK_WRITE | `git push`、`gh pr merge` | 変換の対象外です | denyは承認で覆せず、PRを作れなくなるため |
| INSTALL | `npm install <パッケージ>` | 変換の対象外です | 同上。依存を追加できなくなるため |

`deny`はユーザーが承認しても通せません。確認を出せない埋め合わせは、これまで確認して通していた作業が残る範囲にとどめています。

タグは手で書くのではなく、`scripts/generate-permissions.py`が情報源のglobの先頭から機械的に決めます。`~/`で始まるルールは`[SECRET_PATH]`、`**/`で始まるルールは`[SECRET_NAME]`です。

変換は理由文の先頭タグに依存するため、文言を変えるとエラーを出さないまま止まります。`codex/tests/ask-fallback.test.sh`が検査します。

### 残っている限界

Codexでは`git push`・`npm install`・`DELETE FROM`の確認が出ません。Codexが`ask`を解釈するようになれば解消します。

変換はこのリポジトリの設定です（`codex/hooks/wrap/pre-tool-use.sh`）。変換が必要になった理由は実測2026-08-31で確認しました。

## 6. Codexには許可・拒否リストがない

Claude CodeとCursor CLIは許可・拒否リストを持ちますが、Codex CLIは持ちません。そのため拒否ルールはシェル層の`bash-guard.sh`に集約し、3つのCLIで同じ判定が出る形にしています。

Codexが扱えるツールは`shell`・`exec_command`・`apply_patch`の3つだけで、ファイル読み取り専用のツールがありません。読み取りがすべてシェルを通るため、シェル層だけで全経路を覆えます。

Claude CodeとCursor CLIは`Read`や`Glob`というツール層の読み取り経路を持ち、これはシェル層では捕捉できません。両CLIには許可・拒否リストも必要です。

### 2つの層は互いの穴を埋める

| 層 | 見えるもの | 塞げない例 |
|---|---|---|
| ツール層 | 実際のパスとツール引数 | シェル経由の実行 |
| シェル層 | コマンドの文字列だけ | パスを変数へ分割して組み立てる書き方 |

シェル層だけで完結させようとすると正規表現が際限なく増え、誤検知が実害になります。

Codexのツールが3つだけである点は実測2026-08-31（codex-cli 0.149.1）で確認しました。集約の方針はこのリポジトリの設定です（`claude/hooks/pre-tool-use/bash-guard.sh`）。

## 7. Codexのsandbox機構は採用しない

Codex CLIには`[permissions.<名前>]`プロファイルがあり、macOSの`sandbox-exec`によってOS層でパスを遮断できます。文字列の照合より強い保護ですが、採用していません。

sandboxはプロセス単位でしか判定できず、「エージェントが盗み読む」と「gitやghが正しく使う」を区別できないためです。2026-08-31にcodex-cli 0.149.1で実測した副作用です。

| 拒否したパス | 副作用 |
|---|---|
| ssh鍵のディレクトリ全体 | `git push`と`git pull`が失敗します（`known_hosts`を読めないため） |
| ghの設定ディレクトリ全体 | ghが起動しません |
| キーチェーン | ghが401で認証できません |
| npmの認証設定ファイル | 認証が必要なパッケージのインストールが失敗します |
| 環境変数ファイル | エラーが出ないまま、環境変数が定義されずに終わります |

最後の1つがとくに問題です。Viteでの実測では、ビルドも開発サーバーの起動も成功したまま、実行時に値が定義されていない状態になりました。原因が権限設定にあると気づけません。

### 通信はドメイン単位で制御できない

`allowed_domains`などの設定項目は存在しますが、実測ではCodexがいずれも無視しました。macOSの`sandbox-exec`はTCP接続の可否しか判定できないためです。結果としてCodexの通信は全開か全閉の二択になります。

このため、localhostへ接続するテスト（StorybookやPlaywright）の承認は残ります。承認を消すには外部通信も承認なしで通す必要があり、セキュリティが下がります。

根拠はすべて実測2026-08-31（codex-cli 0.149.1で`codex sandbox -P <名前>`とTUIにより確認）です。副作用は設定項目の説明から導いたものではなく、実際に遮断して観察した結果です。

## 8. 承認の残り方が違う

| CLI | 承認の保存先 | `setup.sh`との関係 |
|---|---|---|
| Claude Code | `claude/settings.json`（dotfiles管理） | 情報源そのもの |
| Cursor CLI | Cursorが`~/.cursor/cli-config.json`へ追記します | 次の実行で消えます |
| Codex CLI | セッション内に閉じます | 影響しません |

Cursorの追記が消えるのは許容している挙動です。設定の情報源をdotfilesに1つだけ持ち、`cli-config.json`は反映先として扱います。恒久的に残したい許可は`claude/settings.json`へ書きます。

`~/.codex/config.toml`に残るのは`[projects.*]`のtrust_levelと`[hooks.state.*]`のtrusted_hashだけで、承認そのものは蓄積しません。

根拠は実測2026-08-31（承認後の各ファイルの差分を確認）です。

## 9. Cursor CLI固有の挙動

### allowlistに一致してもhookは呼ばれる

ユーザーがセッション中に`Shell(head)`のようなコマンドを承認しても、`beforeShellExecution`のhookは呼ばれ、拒否が優先されます（2026-08-31実測）。承認したコマンドが拒否ルールを無効化することはありません。

### Claude Code互換hookを二重に実行する

Cursor CLIは`~/.cursor/hooks.json`のアダプターに加えて、`~/.claude/settings.json`に登録されたhookも直接実行します（2026-08-21実測）。エージェントには2通の文面が連結されて届きます。

`cursor/hooks/lib/cursor-io.sh`がCursor形式のペイロードを変換する際に`cursor_version`キーを落とすため、hook本体は2回目の呼び出しだけを識別して終了します。

### CLIではシェル実行の経路しかhookで守れない

cursor-agent（Cursor CLI）が送るhookイベントは`beforeShellExecution`と`afterShellExecution`だけです（公式）。`cursor/hooks.json`には5種類のイベントへ15個のhookを登録していますが、CLIで動くのはシェル実行前の5個だけです。残る10個が動くのはIDEのAgentでの利用時です。

| 経路 | CLIで働く仕組み |
|---|---|
| シェル実行 | `beforeShellExecution`のhook5個と、`permissions`の`Shell()`の拒否 |
| ファイル読み取り | `permissions`の`Read()`の拒否だけ |
| ファイル編集 | `permissions`の`Write()`の拒否と、既定の承認ダイアログだけ。hookは動きません |
| コミット | lefthookのpre-commit。CLIの種類に依存せず、人手のコミットでも働きます |
| 応答の終了時 | 何も働きません |

CLIで動かないhookは次の10個です。

| hook | 止めていたもの | CLIでの代わり |
|---|---|---|
| branch-guard | 保護ブランチ上での直接編集 | lefthookの`protected-branch`が、保護ブランチ上のコミットを止めます |
| plan-guard | 計画を書く前の実装着手 | ありません。SessionStartが作る基準時刻ファイルを前提に判定するため、CLIでは常に通過します |
| file-protect | 認証情報・秘密鍵・`.git/`・lockfileへの書き込み | `permissions`の`Write()`の拒否21パターンが同じ範囲を止めます |
| mermaid-guard（前後2個） | 壊れたmermaid記法の混入 | lefthookの`mermaid`が、`*.md`を対象に同じ検査をします |
| session-start | セッション開始時の情報表示 | ありません |
| track-edited-files、install | 編集ファイルの記録、依存の再導入 | ありません |
| textlint | 日本語の文章検査 | lefthookの`textlint`が、`*.md`を対象に同じ検査をします |
| format、typecheck（2個） | 整形と型検査の実行 | ありません。lefthookに対応するジョブが無く、CLIでは実行されないまま残ります |

### 実害と使い分け

ファイル編集そのものを止める仕組みは、`permissions`の`deny`と既定の承認ダイアログの2つです。denyに一致する書き込みは、承認を求められずに拒否されます。それ以外は`cursor/cli-permissions.json`の`allow`に`Write()`の項目がないため、編集のたびに承認を求められます。ただしダイアログは「保護ブランチにいる」「計画がない」といった理由を示しません。denyに書けない条件の判断は、ユーザー側に残ります。

保護ブランチとmermaidは、編集の瞬間ではなくコミットの瞬間にlefthookが止めます。編集してから気づくまでに間が空きますが、CLIの種類にも人手かどうかにも依存せず働きます。plan-guardに相当する仕組みは、CLIにはありません。計画の有無を`permissions`の記法で書けず、`plan/`はコミット対象外のためです。

この前提から、次の使い分けになります。

| 状況 | 判断 |
|---|---|
| ファイルを書かせる作業 | 計画を先に書きます。plan-guardがCLIでは働かないためです |
| CLIで作業する場合 | 承認を省略する起動オプション（`--force`など）を使いません。ダイアログが唯一の歯止めであるためです |
| CLIでの一括承認 | ツール単位の恒久承認をしません。承認は`~/.cursor/cli-config.json`へ残り、以後の編集が無言で通ります |
| 非対話でのCLI実行 | ダイアログが出ないため、ファイル編集の歯止めが`permissions`の拒否とlefthookだけになります |
| 整形と検査 | CLIでは自動で走りません。textlintはコミット時のlefthookが検出しますが、整形と型検査は受け皿が無く、実行されないまま残ります |

イベントの種類は公式です。登録の内容と`allow`に`Write()`がないことはこのリポジトリの設定です（`cursor/hooks.json`、`cursor/cli-permissions.json`）。

### tool_inputに`description`がない

Cursor CLIのペイロードは`command`・`cwd`・`timeout`だけです。エージェントが目的を書いても、hookには届きません。目的の記載を要求する判定は、Cursorでは必ず失敗します。

根拠は3つとも実測（allowlistとhookの優先順位は2026-08-31、二重実行とペイロードの内容は2026-08-21）です。二重実行の仕様は公式ドキュメントで確認できていません。

## 10. hookの登録形式が違う

同じhook本体を、3つのCLIが別々のイベント名で呼びます。

| タイミング | Claude Code | Cursor CLI | Codex CLI |
|---|---|---|---|
| セッション開始 | `SessionStart` | `sessionStart`（CLIでは呼ばれません） | `SessionStart` |
| シェル実行前 | `PreToolUse`（matcher `Bash`） | `beforeShellExecution` | `PreToolUse`（matcher `^Bash$`） |
| ファイル編集前 | `PreToolUse`（matcher `Edit`ほか） | `preToolUse`（matcher `Write`。CLIでは呼ばれません） | `PreToolUse`（matcher `^(Edit\|Write\|MultiEdit)$`） |
| ファイル編集後 | `PostToolUse` | `postToolUse`（CLIでは呼ばれません） | `PostToolUse` |
| 応答の終了時 | `Stop` | `stop`（CLIでは呼ばれません） | `Stop` |

| 項目 | Claude Code | Cursor CLI | Codex CLI |
|---|---|---|---|
| 登録ファイル | `claude/settings.json`の`hooks` | `cursor/hooks.json` | `codex/hooks.json` |
| 呼び出し方 | 本体を直接呼びます | `cursor/hooks/adapters/`のアダプター経由 | `codex/hooks/wrap/`のラッパ経由 |
| タイムアウト超過時 | そのまま通します | `failClosed`で指定します | そのまま通します |

cursor-agent（Cursor CLI）が送るのは`beforeShellExecution`と`afterShellExecution`だけです（公式）。`cursor/hooks.json`には他のイベントも登録していますが、これらが動くのはIDEのAgentでの利用時です。CLIでガードが効くのはシェル実行の経路に限られます。

Codexのhookは、TUIの`/hooks`でtrustするまで実行されません。trust状態は`~/.codex/config.toml`の`[hooks.state.*]`に保存され、dotfilesの管理対象外です。`codex/hooks.json`やラッパを変えたあとは再trustが必要です。

イベント名と`failClosed`の既定は公式です。登録の内容はこのリポジトリの設定です（`claude/settings.json`、`cursor/hooks.json`、`codex/hooks.json`）。trustの要否は実測2026-08-31で確認しました。

## 11. ファイル配置と参照の違い

| 種類 | Claude Code | Cursor CLI | Codex CLI |
|---|---|---|---|
| グローバル指示 | `~/.claude/CLAUDE.md` | `~/.cursor/rules/global-instructions.mdc`（生成物） | `~/.codex/AGENTS.md` |
| スキル | `~/.claude/skills` | `~/.cursor/skills` | `~/.agents/skills` |
| サブエージェント | `~/.claude/agents`（Markdown） | `~/.cursor/agents`（Markdown） | `~/.codex/agents`（TOML、生成物） |
| ドキュメント参照 | `~/.claude/docs` | Rules内の`@.claude/docs/...` | `~/.claude/docs` |

スキルは3つとも同じ`claude/skills/`を指しますが、リンク先のパスが異なります。

サブエージェントは、CodexだけがTOML形式のため`claude/agents/*/SUBAGENT.md`から生成します。`SUBAGENT.md`を直しただけではCodexへ反映されません。

`commit-message-writer`サブエージェントは、CodexではClaude Codeのtranscript JSONLを読めません。

各CLIが読むパスは公式です。リンクの張り方はこのリポジトリの設定です（`setup.sh`の`SYMLINKS`、`scripts/generate-codex-agents.py`）。

## 12. エージェントがこの差分をどう使うか

作業中に判断が必要になった場合の対応です。

| 状況 | 対応 |
|---|---|
| 拒否ルールを追加・変更する | 生成物ではなく`permissions/deny-rules.json`だけを編集し、`./scripts/generate-permissions.sh`を実行します |
| 許可（`allow`）を恒久的に増やす | `claude/settings.json`へ書きます。`~/.cursor/cli-config.json`への直接の追記は`setup.sh`で消えます |
| グローバル指示を変える | `claude/CLAUDE.md`を編集し、`./scripts/generate-cursor-rules.sh`を実行します |
| サブエージェントを変える | `claude/agents/*/SUBAGENT.md`を編集し、`./scripts/generate-codex-agents.sh`を実行します |
| モデルやstatusLineを変える | CLIごとに別のファイルへ書きます（3節）。1か所の変更では揃いません |
| hookの理由文の文言を変える | 先頭のタグ（`[DESTRUCTIVE]`など）を残します。タグを消すとCodexでの`ask`から`deny`への変換が止まります |
| Codexで`ask`を返す判定を新設する | そのままでは実行されます。取り消せない操作なら`[DESTRUCTIVE]`タグを付けます |
| Cursorで目的の記載を求める判定を書く | 判定の条件から目的の記載を外します。`description`が届かないため、条件に入れると必ず拒否になります |
| CLIごとに挙動が違うと報告を受けた | この文書の該当節を確認し、実測で確かめてから記録を更新します |

## 13. 根拠となるファイル

| 内容 | ファイル |
|---|---|
| 反映の入口 | `setup.sh` |
| 拒否ルールの情報源 | `permissions/deny-rules.json` |
| 生成スクリプト | `scripts/generate-permissions.py`、`scripts/generate-cursor-rules.py`、`scripts/generate-codex-agents.py` |
| 記法の変換 | `scripts/sync-cursor-cli-permissions.sh` |
| マージ | `scripts/merge-codex-config.sh`、`scripts/merge-cursor-cli-config.sh` |
| シェル層の判定 | `claude/hooks/pre-tool-use/bash-guard.sh` |
| Codexの`ask`変換 | `codex/hooks/wrap/pre-tool-use.sh` |
| Cursorのペイロード変換 | `cursor/hooks/lib/cursor-io.sh` |
| 変換が止まらないことの検査 | `codex/tests/ask-fallback.test.sh` |
| 生成物のずれの検査 | `lefthook.yml`、`.github/workflows/permissions-test.yml` |
| セキュリティ設計の全体像 | `claude/SECURITY.md` |
