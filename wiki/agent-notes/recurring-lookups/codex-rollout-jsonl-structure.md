# Codex rollout JSONLの実物構造

## 目的

エージェントへの質問ではなく、Codexのログに残った事実をもとに作業の経過（対象セッション・コマンドの成否・人の発言・トークン消費）を判断したいときに開きます。

## 対象

`~/.codex/sessions/YYYY/MM/DD/rollout-*.jsonl`（Codex CLIの作業ログ）です。各行は`{ordinal, payload, timestamp, type}`のJSONオブジェクトです。

## 方法

要約を取得するには`claude/skills/x-agent-notes/scripts/codex-log-summary.sh`を`--cwd`（必要なら`--since`・`--file`・`--section`）付きで実行します。JSONLを直接調べる場合は次の要点で扱います。

- セッションを特定するには`session_meta.payload.cwd`の一致で絞ります。`payload.git`は現行フォーマットに存在しないため、gitハッシュ照合は使えません
- `session_meta`は2件記録される場合があります。サブエージェントを起動したセッションでは親CLIとサブエージェントの両方が記録されるため、両方の`cwd`を照合対象にします
- コマンド失敗を判定するには`custom_tool_call_output.payload.output`を確認します。この値は配列で、`output[0].text`の先頭が`"Script failed"`なら失敗です。終了コードの数値は記録されません
- 「人の発言」を判別するには`response_item.payload.role == "user"`のテキストを確認します。先頭が`#`（AGENTS.md）・`<`（XMLタグ）・`Use the subagent definition at`・`コミット計画を作成してください`などのスキル定型で始まるものはシステム挿入として除外します
- トークン消費は`event_msg.payload.type == "token_count"`の`info.total_token_usage.total_tokens`（累積）で確認できます。週次枠は`rate_limits.primary.used_percent`と`window_minutes: 10080`で確認できます

## 根拠

| 項目 | 内容 |
|---|---|
| 状態 | 実測済み（`payload.git`記述の由来と、人の発言ヒューリスティックの誤検出率は検証していません） |
| 情報源 | `~/.codex/sessions/2026/08/19/rollout-2026-08-19T14-25-26-*.jsonl`（199行・1.1MB）と`~/.codex/sessions/`配下の直近20ファイルへの`jq`サンプリング |

### typeの分布例（199行の1セッション）

| type | 件数 |
|---|---|
| response_item | 96 |
| event_msg | 90 |
| world_state | 4 |
| inter_agent_communication_metadata | 4 |
| turn_context | 3 |
| session_meta | 2 |

### 圧縮の実測

`codex-log-summary.sh`と同じ抽出方式（files・utterances・tools・failures・tokensの5セクション）で、3.6MBのrolloutを25KBに圧縮（0.69%）できることを実測しました。

## 未解決

| 疑問 | なぜ残すか |
|---|---|
| 元計画に書かれた「`payload.git`を持つ」記述の由来 | 過去のCLIバージョンで存在した可能性があります。`cli_version`とリリースノートを照合して確認します |
| 「人の実発言」ヒューリスティックの誤検出率 | 実データでの精度の検証が必要です。スキルを運用する中で測ります |

## 更新履歴

| 日時 | 変更 |
|---|---|
| 2026-08-21 | x-agent-notesスキルの書式（目的・対象・方法＋根拠）に再構成し、実装済みの`codex-log-summary.sh`への参照を追加しました |
| 2026-08-20 12:59 JST | 情報源と抽出スクリプト節から個人リポジトリへの参照を外し、記録単体で読める形に整えました |
| 2026-08-20 | 初版（Codex log knowledgeプロジェクトのサンプル1件目） |
