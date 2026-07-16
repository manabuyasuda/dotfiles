#!/usr/bin/env bash
# notify Cursor アダプタの回帰テスト（terminal-notifier がある場合のみ）

set -u

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ADAPTER="$SCRIPT_DIR/../hooks/adapters/notify.sh"

if ! command -v terminal-notifier &>/dev/null; then
  echo "SKIP: terminal-notifier 未インストール"
  exit 0
fi

# 通知が飛ぶだけなので exit 0 を確認
if jq -nc --arg m "adapter test" --arg c "/tmp" '{message:$m, cwd:$c}' | bash "$ADAPTER"; then
  echo "ok   - T1 notify adapter exit 0"
  exit 0
fi
echo "FAIL - T1 notify adapter failed"
exit 1
