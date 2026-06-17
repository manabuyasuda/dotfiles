#!/usr/bin/env bash
# =============================================================================
# pre-tool-use/plan-guard.sh — 実装着手前に plan/ への計画作成を強制
# =============================================================================
# フック  : PreToolUse（Edit / MultiEdit / Write）
# 役割   : 実装系のファイル編集に着手する前に、作業の計画が plan/ に書かれているかを
#          検査し、無ければ exit 2 でハードブロックする。CLAUDE.md「作業記録ディレクトリ」
#          の「実装前に plan/ に計画を書く」ルールを、注意力に頼らず構造的に強制する。
#
# 発火モデル: セッション内で一度だけゲートする（fire-once）。
#          - そのセッションで最初に実装系編集が通過した時点で解除フラグを記録し、以後は
#            plan/ の状態に関わらず止めない（誤ブロックを最小化する）。
#          - 解除前は、plan/ に非空ファイルが無い限り実装系編集をブロックし続ける
#            （計画を書かせるため）。計画を書いて一度通れば、その後は黙る。
#          記録は ${TMPDIR:-/tmp}/plan-guard-<session_id>。
#
# 対象範囲: 作業記録ディレクトリ（explore/ plan/ retrospective/）配下への書き込みは
#          常に対象外（でないと計画ファイル自体を作れず無限ロックになる）。それ以外の
#          すべてのファイル（*.md を含む）が対象。
#
# プロジェクトルート: hook 入力の .cwd を起点に git rev-parse --show-toplevel で求める
#          （worktree に追従する）。git 管理外なら .cwd をそのまま使う。plan/ はこの
#          ルート直下にある前提。
#
# 終了コード:
#   0 → 通過（対象外パス / 計画あり / 解除済み / フェイルオープン）
#   2 → ハードブロック（計画が無いまま実装系編集に着手）
#
# 入力 : stdin の JSON（.tool_input.file_path | .tool_input.path / .session_id / .cwd）
# =============================================================================

# jq が無ければ判定できないのでフェイルオープン
command -v jq &>/dev/null || exit 0

INPUT=$(cat)

# file_path / session_id / cwd を1回の jq でまとめて取得する（同一 stdin を複数回 parse
# しない）。file_path は改行を含み得るため read（改行で切れる）ではなく NUL 区切り＋
# mapfile で分割する。各フィールドを NUL 終端して連結し、末尾要素のズレを防ぐ。
mapfile -d '' -t _fields < <(
  jq -j '[.tool_input.file_path // .tool_input.path // "", .session_id // "", .cwd // ""]
         | join("\u0000") + "\u0000"' <<<"$INPUT"
)
FILE_PATH="${_fields[0]:-}"
SESSION_ID="${_fields[1]:-}"
CWD="${_fields[2]:-}"

# file_path が取れない（対象ツールでない等）なら判定できないので通過
[ -z "$FILE_PATH" ] && exit 0
# session_id が無いと fire-once を追跡できない。毎回ブロックして作業を不当に止めるより、
# 追跡可能な通常時のみ強制する方が安全なのでフェイルオープン。
[ -z "$SESSION_ID" ] && exit 0

# 相対パスは cwd 基準で絶対化する
case "$FILE_PATH" in
  /*) ;;
  *) FILE_PATH="${CWD:-$(pwd)}/$FILE_PATH";;
esac

# プロジェクトルート（plan/ の所在）。worktree に追従させるため .cwd を起点にする。
ROOT=$(git -C "${CWD:-$(pwd)}" rev-parse --show-toplevel 2>/dev/null)
[ -z "$ROOT" ] && ROOT="${CWD:-$(pwd)}"

# 作業記録ディレクトリ配下は常に対象外（計画ファイル自体の作成をブロックしないため）
case "$FILE_PATH" in
  "$ROOT"/explore/*|"$ROOT"/plan/*|"$ROOT"/retrospective/*) exit 0;;
esac

STATE_FILE="${TMPDIR:-/tmp}/plan-guard-${SESSION_ID}"

# 既にこのセッションで一度ゲートを通過済みなら、以後は止めない（fire-once）
[ -f "$STATE_FILE" ] && exit 0

# plan/ に非空の通常ファイルが1つでもあれば「計画あり」とみなす（空の .gitkeep 等は除外）。
if [ -n "$(find "$ROOT/plan" -type f ! -empty 2>/dev/null | head -n1)" ]; then
  # 計画あり → ゲート解除を記録して通過
  printf 'cleared' > "$STATE_FILE" 2>/dev/null
  exit 0
fi

# 計画なし → ハードブロック（解除は記録しない＝計画を書くまで止め続ける）
jq -n --arg msg "ERROR: この作業の計画が plan/ にありません。WHY: 実装に着手する前にアプローチ・目的・手順を plan/ に書き出すルールです（CLAUDE.md「作業記録ディレクトリ」）。FIX: plan/<task>.md に今回の計画を書いてから実装系の編集を再実行してください。explore/・plan/・retrospective/ への書き込みは対象外です。" \
  '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":$msg}}'
exit 2
