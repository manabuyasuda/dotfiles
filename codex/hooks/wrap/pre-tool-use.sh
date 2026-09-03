#!/usr/bin/env bash
# wrap/pre-tool-use.sh — claude/hooks/pre-tool-use/* の Codex ラッパ（stdin をそのまま渡す）

set -euo pipefail

LIB_DIR="$(cd "$(dirname "$0")/../lib" && pwd)"
# shellcheck source=../lib/codex-io.sh
source "$LIB_DIR/codex-io.sh"

HOOK_NAME="${1:-}"
if [[ -z "$HOOK_NAME" ]]; then
  echo "pre-tool-use wrap: hook name required" >&2
  exit 0
fi

codex_io_load_settings_env

HOOK="$(cursor_io_dotfiles_dir)/claude/hooks/pre-tool-use/${HOOK_NAME}"
if [[ ! -f "$HOOK" ]]; then
  echo "pre-tool-use wrap: hook not found: $HOOK" >&2
  exit 0
fi

INPUT=$(cat)

OUTPUT=$(printf '%s' "$INPUT" | bash "$HOOK" 2>/dev/null || true)

# Codex CLI は permissionDecision: "ask" を無視してコマンドをそのまま実行する
# （2026-08-31 実測。plan/codex-ask-decision-check.md に手順と結果）。
# deny は伝わるため、確認できないぶんを deny へ落として補う。
#
# 変換するのは2つのタグが付いた ask だけ。
#   [DESTRUCTIVE] rm / git reset --hard / git push --force など、取り消せない操作
#   [SECRET_PATH] ホームにある特定の認証情報ファイル（~/.ssh/ ~/.aws/ ~/.netrc など）への一致
# Why not: [SECRET_NAME] は変換しない。これは `**/.env*` のように、どこにでも現れ得る名前への
#          一致で、`rg 'import.meta.env' src/` のような無害な命令が大半を占める。deny にすると
#          Codex では承認で覆せず、恒久的に実行できなくなる。読み取りの実体があるものは
#          [SECRET_PATH] 側に入るため、ここを外しても認証情報の読み取りは止まる。
# Why not: ask を全部 deny にしない。git push（NETWORK_WRITE）と npm install（INSTALL）まで
#          止まり、Codex で日常の作業ができなくなる。確認を出せないことの埋め合わせが、
#          確認して通していた作業を不可能にする形になっては本末転倒。
# Why not: --force-with-lease は DESTRUCTIVE ではない（classify() が NETWORK_WRITE に分類する）。
#          claude/skills/x-rebasing-feature-branch が使うため、止めると rebase が完了しない。
#
# タグは bash-guard.sh の理由文の先頭にある文字列に依存する。
# 文言が変わると変換が静かに止まるため、codex/tests/ask-fallback.test.sh で検査する。
#
# 判定が出たときだけ jq を起動する。通過するコマンドでは OUTPUT が空で、それが大半を占める。
# Why not: ここで ask かどうかを調べない。同じ条件を bash と jq の2箇所に書くことになり、
#          片方だけ直すと変換が静かに止まる。ask の判定は jq の式1箇所に置く。
if [[ -n "$OUTPUT" ]]; then
  OUTPUT=$(printf '%s' "$OUTPUT" | jq -c '
    if (.hookSpecificOutput.permissionDecision == "ask")
       and (.hookSpecificOutput.permissionDecisionReason
            | test("^\\[(DESTRUCTIVE|SECRET_PATH)\\]"))
    then .hookSpecificOutput.permissionDecision = "deny"
       | .hookSpecificOutput.permissionDecisionReason +=
           " NOTE: Codex CLI は確認を表示できないため拒否しました。実行が必要な場合はユーザー自身が実行してください。"
    else . end
  ' 2>/dev/null || printf '%s' "$OUTPUT")
fi

# 出力なし（通過）のときは何も書かない。空行を書くと JSON として読まれる。
[[ -n "$OUTPUT" ]] && printf '%s\n' "$OUTPUT"
exit 0
