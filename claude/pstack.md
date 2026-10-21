# pstack

pstackは、エージェントに設計・検証・レビューの作業の流れを守らせるためのスキル集です。入口の`poteto-mode`が、依頼の内容に合わせて23種類の作業の流れから1つを選びます。作業の流れには、バグ修正・機能追加・リファクタリング・PRの作成などの開発作業があります。エージェントは、作業の流れの各段階で`how`・`architect`・`interrogate`などのスキルを読み込んで実行します。

このファイルは、dotfilesでpstackを導入・運用・削除するときの手順と、導入時に決めたことを1か所にまとめたものです。

配布元は次の2つです。

- 公式版：[cursor/pluginsのpstack](https://github.com/cursor/plugins/tree/main/pstack)。作者はLauren Tanです。GitHubでの名前はpotetoです
- 移植版：[michael-denyer/pstack-claude](https://github.com/michael-denyer/pstack-claude)。第三者がClaude CodeやCodexなどへ移植した版です。ライセンスはMITです

## 導入状況

| CLI | 配布元 | 状態（2026-10-21） | 設定が書き込まれる場所 |
|---|---|---|---|
| Claude Code | 移植版（0.9.96） | 導入済み | `claude/settings.json`の`enabledPlugins`と`extraKnownMarketplaces`（dotfilesで管理する） |
| Cursor | 公式版 | 導入済み | IDEチャットは `/add-plugin pstack`。cursor-agent は `cursor-public` マーケットプレイスが組み込み済みなので追加設定不要。`/pstack:setup-pstack` は任意で `~/.cursor/rules/pstack-models.mdc` を作る |
| Codex | 移植版（0.9.96） | 導入済み | `~/.codex/config.toml`（dotfilesのsymlinkではない） |

Claude CodeとCodexでは移植版を使います。移植版には自動起動hook（後述）があり、公式版のClaude Code用プラグインにはないためです。また、公式版にはCodex向けの変換表もありません。Claude Codeでは、最初に公式版0.15.29を導入し、同じ日に移植版へ切り替えました（2026-10-21）。Cursorでは公式版を使います。cursor-agentから使う場合、`cursor-public`マーケットプレイスが最初から入っているので追加のプラグイン設定は要りません。

## 導入手順

Claude Codeには、ターミナルで次のコマンドを実行して導入します。

```bash
claude plugin marketplace add michael-denyer/pstack-claude
claude plugin install pstack@pstack-claude
```

`setup.sh`をまだ実行していないPCでは、次の順に実行するとClaude Codeに導入できます。マーケットプレイスの登録は`extraKnownMarketplaces`に記録されているので、`claude plugin marketplace add`は実行しなくてかまいません。

1. `setup.sh`を実行して、`claude/settings.json`のsymlinkを作成します
2. `claude plugin install pstack@pstack-claude`を実行します

Cursor IDEのチャット欄では、次のコマンドを実行して導入します。

```text
/add-plugin pstack
```

cursor-agentから使う場合、`cursor-public`マーケットプレイスが組み込み済みなので、`/add-plugin pstack`を実行しなくてもpstackスキルが利用できます。

Codexには、ターミナルで次のコマンドを実行して導入します。

```bash
codex plugin marketplace add michael-denyer/pstack-claude
codex plugin add pstack@pstack-claude
```

実行したあと、Codexを起動して`/hooks`で移植版のhookを信頼します。

移植版のhook（以下、自動起動hook）は、セッションの開始時に、複数のファイルにまたがる変更・設計・原因を特定できていないバグの依頼では`poteto-mode`を起動するよう指示する文を出力するSessionStart hookです。

`setup-pstack`は任意です。実行すると、役割ごとに使うモデルを選んだ設定ファイルが作られます。移植版では、自動起動hookが選んだ結果のファイル（Claude Codeは`~/.claude/pstack-models.md`、Codexは`~/.codex/pstack-models.md`）を読みます。Claude Codeの`~/.claude/pstack-models.md`は、dotfilesの`claude/pstack-models.md`へのsymlinkで、`setup.sh`が作ります。`claude/CLAUDE.md`の末尾にある`@~/.claude/pstack-models.md`で、毎回のセッションに読み込まれます。`claude/CLAUDE.md`は`~/.codex/AGENTS.md`としてもリンクされているので、Codexもこの行を文字列として読みます。この副作用は許容し、Codexで問題が起きたときに見直します（2026-10-21）。Cursor（公式版）では`~/.cursor/rules/pstack-models.mdc`に書かれます。移植版の設定ファイルに`session hook: off`と書くと、自動起動hookは指示文を出力しません。

## 使い方

| 使う場面 | Claude Code | Cursor（公式版） |
|---|---|---|
| 複数のファイルにまたがる変更、設計の判断、原因を特定できていないバグ。pstackの作業の流れ全体を使う | `/pstack:poteto-mode <依頼>` | `/poteto-mode <依頼>` |
| どのスキルを使えばよいか決められない場合 | `/pstack:poteto-help` | `/poteto-help` |
| コードの仕組みや、そう作られた経緯を調べるとき | `/pstack:how`、`/pstack:why`、`/pstack:teach` | `/how`、`/why`、`/teach` |
| 差分の欠陥や、変更の影響範囲を調べるとき | `/pstack:interrogate`、`/pstack:blast-radius` | `/interrogate`、`/blast-radius` |
| 関数やモジュールの境界をまたぐ実装を始める前 | `/pstack:architect` | `/architect` |
| 失敗するテストを先に書いてからバグを直すとき | `/pstack:tdd` | `/tdd` |

Cursorは公式版なので、自動起動hookがなく、使うときにスラッシュコマンドで指定します。公式版ではスキル名がそのままコマンドになるため、`/poteto-mode <依頼>`、`/how <依頼>`、`/architect <依頼>`のように呼び出します。Codexでは`pstack:poteto-mode`のように名前で依頼します。

Claude CodeとCodexでは、自動起動hookを使います（2026-10-21）。`poteto-mode`の付け忘れを防ぐためです。そのため、複数のファイルにまたがる変更などを頼むと、pstackの作業の流れが`plan-writer`などの既存の運用より先に動くことがあります。

移植版では、65スキルのうち64スキルのSKILL.mdに`disable-model-invocation: true`が設定されていません（0.9.96で確認）。そのため、Claude Codeは依頼の内容から`poteto-mode`などのスキルを自分で起動できます。公式版では多くのスキルに`disable-model-invocation: true`が設定されているため、`/poteto-mode`や`/architect`などのスラッシュコマンドを入力しないと起動しません。

## 既存のスキルとの関係

| 区分 | スキル・サブエージェント | 扱い |
|---|---|---|
| 続けて使う | `x-japanese-writing-review`、`x-grill-me`とその起動先の`x-grilling`、`x-commit`とその起動先の`commit-message-writer`、`explore-writer`、`plan-writer` | pstackを導入しても残す |
| pstackに同じ役割のスキルがある | `x-teach-me`、`x-disprove`、`x-code-review-judgment`、`x-code-review-static`、`x-code-review-git-history`、`critical-doc-review`、`x-test-review`、`x-grill-with-goal`、`x-check-me`、`x-agent-notes`、`decompose` | pstackを試用して、置き換えられると確かめたスキルから削除する |
| pstackに同じ役割のスキルがない | `x-figma-extract`、`x-figma-implement`、`x-japanese-reasoning-review`、`x-why-so`、`x-cleanup-merged-branches`、`x-rebasing-feature-branch`、`verify-npm-package-security` | 残す。`x-rebasing-feature-branch`はCodexのhook（`codex/hooks/wrap/pre-tool-use.sh`）が、`verify-npm-package-security`はパッケージのインストール前に動くhookが前提にしている |

試用期間は決めません。pstackのスキルで置き換えられたと判断したときに、ユーザーが削除を決めます（2026-10-21）。

## pstackの方針とdotfilesの方針が異なる点

| pstackの方針 | dotfilesの方針 | 2026-10-21時点の扱い |
|---|---|---|
| `principle-never-block-on-the-human`：ユーザーに承認を求めずに進め、結果をあとから見せる。承認を求めるのは取り消せない操作に限る | 判断の権限はユーザーにある（`claude/CLAUDE.md`の大原則2） | 自動起動hookが出力する指示文には「CLAUDE.mdなどのユーザーの指示を優先する」と書かれている |
| `autopilot-full`、`shipping`：複数のPRを並列に作り、検証してからマージまで進める | コミットとpushは明示の指示を待つ | push・マージを止める仕組みは追加しない。Claude CodeとCursorでは`bash-guard.sh`が`git push`と`gh pr merge`の前に承認を求める。ただし、Codexでは承認を求めずに実行されてしまう |
| `no-comments`：レビューの前にコードコメントを削除する。`poteto-mode`はPRを作る前に毎回実行する | コードコメントにはWhy notを書く | 当面は実行させる。削除されたコメントはPRの差分で確かめる |

push・マージを止める仕組みを追加しなかった理由は、次の3つです（2026-10-21）。

- 3つのCLIの履歴（Claude Code 1300セッション、Codex 581セッション、Cursor 532セッション）で、ユーザーが依頼していないマージは0件でした。Codexでは、pushとマージのどちらも0件でした
- マージはrevertで戻せます
- ユーザーが担当している業務では、マージしても、リリースは実行されません

`autopilot-full`のような、`autopilot-`で始まるスキルと、`shipping`は、Cursorのクラウドエージェントと`/loop`を前提にしています。Claude Codeでは、プラグインに含まれる変換表が、Claude Codeに同じ機能がない段階を飛ばします。

## 更新

Claude Codeでは、ターミナルで次のコマンドを実行して更新します。

```bash
claude plugin marketplace update pstack-claude
claude plugin update pstack@pstack-claude
```

Codexでは、ターミナルで次のコマンドを実行して更新します。

```bash
codex plugin marketplace upgrade
```

移植版を更新して自動起動hookの定義が変わったときは、Codexで`/hooks`を開いて、自動起動hookを信頼し直します。Claude Codeでは、信頼し直す操作は要りません。

## 削除手順

Claude Codeからは、次のコマンドで削除します。

```bash
claude plugin uninstall pstack@pstack-claude
claude plugin marketplace remove pstack-claude
```

実行したあと、次の順に作業します。

1. `git diff`で、`claude/settings.json`の`enabledPlugins`に`pstack@pstack-claude`が残っていないことを確かめます
2. 同じく`extraKnownMarketplaces`に`pstack-claude`が残っていないことを確かめます
3. `claude/pstack-models.md`を削除し、`setup.sh`の`SYMLINKS`から`claude/pstack-models.md:.claude/pstack-models.md`の行を削除します
4. `claude/CLAUDE.md`の末尾にある`@~/.claude/pstack-models.md`の行を削除します

Codexからは、次のコマンドで削除します。

```bash
codex plugin remove pstack@pstack-claude
codex plugin marketplace remove pstack-claude
```

`~/.codex/pstack-models.md`があれば削除します。

Cursorでの削除方法は、まだ確認していません。

pstackへの置き換えで削除した既存のスキルは、gitの履歴から戻します。既存のスキルを削除したときは、削除したコミットのハッシュをこの節へ追記します。
