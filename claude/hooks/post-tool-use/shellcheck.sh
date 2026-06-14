#!/usr/bin/env bash
# =============================================================================
# post-tool-use/shellcheck.sh — 編集後の shell 静的解析
# =============================================================================
# フック  : PostToolUse（Edit / MultiEdit / Write）
# 役割   : .sh ファイルを編集するたびに shellcheck で静的解析し、
#          引用符忘れ・未定義変数など「黙って誤動作する」shell 特有のバグを
#          エージェントがコミット前に修正できるようにする。
#
# 対象ファイル: *.sh のみ（それ以外は即 exit 0）
#
# しきい値: --severity=warning（error + warning を検出）
#          info / style はブロックしない（既存スクリプトの軽微な指摘を許容する）。
#
# ブロッキング設計:
#   warning 以上が見つかったら exit 1 で feedback を返し、エージェントに修正させる。
#   format.sh と同じ思想（壊れたスクリプトのまま次の作業へ進ませない）。
#
# 未インストール時（shellcheck コマンドが無い環境）:
#   検証をスキップして exit 0（ローカルにツールが無くても作業を止めない）。
#   未インストール環境の取りこぼしは pre-commit / CI 側で補完する。
#
# 出力（feedback）:
#   違反なし: {"feedback": "shellcheck passed.", "suppressOutput": true}
#   違反あり: gcc 形式の指摘を feedback に載せて exit 1
#
# 入力 : $CLAUDE_TOOL_INPUT_FILE_PATH（編集されたファイルのパス）
# =============================================================================
file="$CLAUDE_TOOL_INPUT_FILE_PATH"

# .sh 以外は対象外
[[ "$file" =~ \.sh$ ]] || exit 0

# 対応 shell（sh/bash/dash/ksh）以外は対象外（zsh など。shellcheck は SC1071 で必ず失敗する）
head -1 "$file" | grep -qE '^#!.*[/ ](sh|bash|dash|ksh)( |$)' || exit 0

# コマンドが無い環境では検証をスキップする（pre-commit / CI で補完する）
command -v shellcheck >/dev/null 2>&1 || exit 0

output=$(shellcheck -f gcc --severity=warning "$file" 2>&1)
if [ -z "$output" ]; then
  echo '{"feedback": "shellcheck passed.", "suppressOutput": true}'
  exit 0
fi

msg="ERROR: shellcheck で warning 以上の指摘が見つかりました。\nWHY: 引用符忘れや未定義変数など、shell が黙って誤動作する原因になります。\nFIX: 下記の指摘を修正してください（意図的な場合のみ該当行に # shellcheck disable=SCxxxx を付けます）。\nファイル: ${file}\n\n${output}"
feedback=$(printf '%s' "$msg" | python3 -c "import json,sys; print(json.dumps({'feedback': sys.stdin.read()}))")
echo "$feedback"
exit 1
