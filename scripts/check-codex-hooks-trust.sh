#!/usr/bin/env bash
# =============================================================================
# check-codex-hooks-trust.sh — Codex CLI の hook の再信頼漏れを止める
# =============================================================================
# 用途   : lefthook の pre-commit から呼ばれ、codex/hooks.json の内容が
#          「最後に信頼した時点」から変わっていたらコミットを止める。
#          --confirm を付けて実行すると、現在の内容を信頼済みとして記録する。
#
# WHY: Codex CLI は hook を「信頼」するまで実行しない。信頼状態は
#      ~/.codex/config.toml の [hooks.state."<パス>:<イベント>:<グループ>:<番号>"]
#      に記録され、TUI の /hooks から与える。キーが hooks.json の配列の添字に
#      依存するため、hook を並べ替えたり途中へ挿入したりすると既存の信頼が
#      別の hook に対応づけられ、警告なしに外れる。そして Codex CLI には
#      permissions の許可・拒否リストが無いため、hook が止まるとシェル実行の
#      判定（dangerous-guard / bash-guard / push-to-main-guard /
#      check-gh-account / verify-package-install）を代わりに止めるものが何も
#      残らない。Claude Code の Bash() deny、Cursor CLI の Shell() deny のような
#      受け皿が無いのは Codex CLI だけである。
#
# Why not: ~/.codex/config.toml の trusted_hash とは照合しない。算出方法が
#          再現できず（コマンド文字列・JSON オブジェクトの sha256 はいずれも
#          不一致、2026-09-03 実測）、正しい値を手元で計算できない。
#
# Why not: [hooks.state] のキーの集合とも照合しない。並べ替えではキーの数も
#          位置も変わらないため、いちばん危険な変更を素通しする。ファイル全体の
#          sha256 なら、追加・削除・並べ替え・コマンドの変更を区別せず捕まえる。
#
# Why not: 記録ファイルはコミットしない。信頼は ~/.codex/config.toml に対して
#          マシンごとに与えるもので、リポジトリで共有できない。
#
# Why not: 環境変数などの回避手段は用意しない。回避手段を残すとエージェントが
#          それを使い、強制にならない。
#
# 終了コード: 0=一致（Codex 未使用でスキップ、--confirm 成功を含む）/ 1=不一致
# =============================================================================

set -u

REPO_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
HOOKS_JSON="$REPO_DIR/codex/hooks.json"
CODEX_CONFIG="$HOME/.codex/config.toml"
FINGERPRINT_FILE="$HOME/.codex/hooks-trusted-fingerprint"

# Codex CLI を使っていない環境には信頼の概念が無いため、何もしない。
if [[ ! -f "$CODEX_CONFIG" ]]; then
  exit 0
fi

if [[ ! -f "$HOOKS_JSON" ]]; then
  echo "codex/hooks.json が見つかりません: $HOOKS_JSON"
  exit 1
fi

current=$(shasum -a 256 "$HOOKS_JSON" | cut -d' ' -f1)

if [[ "${1:-}" == "--confirm" ]]; then
  printf '%s\n' "$current" > "$FINGERPRINT_FILE"
  echo "codex/hooks.json を信頼済みとして記録しました（sha256: ${current:0:12}）。"
  exit 0
fi

recorded=""
[[ -f "$FINGERPRINT_FILE" ]] && recorded=$(cat "$FINGERPRINT_FILE")

if [[ "$current" == "$recorded" ]]; then
  exit 0
fi

if [[ -z "$recorded" ]]; then
  echo "Codex CLI の hook を信頼した記録がありません。"
else
  echo "codex/hooks.json が、最後に信頼した時点から変わっています。"
fi

cat <<'MSG'
Codex CLI は hook を信頼するまで実行しません。信頼が外れると、シェル実行の判定が
何も残らない状態で Codex CLI が動きます。次の手順で信頼し直してください。

  1. codex を起動し、TUI で /hooks を実行して hook を信頼する
  2. bash scripts/check-codex-hooks-trust.sh --confirm

~/.codex/hooks.json はこのリポジトリへのシンボリックリンクです。編集はすでに
反映されているため、setup.sh の再実行は要りません。
MSG

exit 1
