#!/usr/bin/env bash
# =============================================================================
# lib/decision.sh — hook の判定 JSON を組み立てる唯一の合流点
# =============================================================================
# 役割 : deny / ask の JSON を出力し、そのときメッセージの長さを必ず上限内へ収める。
#
# なぜ合流点が要るか:
#   hook の出力の長さが、判定結果ではなく判定対象で決まっていた。判定の種類は
#   有限（deny / ask × 数種類の理由）なのに、メッセージへコマンド全文を埋めていた
#   ため、55行のヒアドキュメントを入力すると55行の deny メッセージが返った。
#   画面がそれで流れ、直後に出る承認ダイアログがユーザーの視界の外へ出て、
#   「指示したのに何も進んでいない」ように見える状態になった（2026-08-31 に発生）。
#   同じ文字列が入力と理由文の2回ぶんエージェントのコンテキストも消費する。
#   各 hook が自前で jq を書いていると上限を強制する場所がないため、ここへ集約する。
#
# 使い方:
#   source "$(dirname "$0")/../lib/decision.sh"
#   _deny() { hook_emit_decision deny PreToolUse "$1"; exit 0; }
#   _deny "ERROR: ... FIX: ... コマンド: $(hook_excerpt "$COMMAND")"
#
# Why not: bash の ${#s} と ${s:0:n} で切らない。どちらもロケール依存で、C ロケール
#          ではバイト単位になり UTF-8 の途中で切れて理由文が壊れる。jq は文字列を
#          コードポイントで扱い、JSON の組み立てでどのみち呼ぶので追加の起動もない。
# Why not: 改行を残さない。複数行のまま返すと画面が流れて承認ダイアログが押し出され、
#          今回の実害がそのまま再現する。読みやすさより、ダイアログが見えることを優先する。
# =============================================================================

# 理由文全体の上限（文字数）。ここは最後の砦で、通常は効かない。理由文の長さは
# 「hook ごとに固定の定型文」＋「hook_excerpt で 120 文字に抑えた可変部分」で
# 決まるため、可変部分を抜粋している限りこの上限には届かない。
#
# 400 という値の根拠（2026-09-02 実測。実際のコマンドを各 hook へ通して計測）:
#   push-to-main-guard   `git push --force origin main`      110文字 / 100桁端末で2行
#   dangerous-guard      `rm -rf build`                      117文字 / 2行
#   bash-guard (deny)    `cat <秘密ファイル>`                159文字 / 3行
#   bash-guard (ask)     `grep -rn '<環境変数>' src/`        194文字 / 4行
#   verify-package-install `npm install lodash`              278文字 / 5行
# 実コマンドで上限に当たったものはない。当たった場合でも全角で 7〜10 行に収まり、
# この仕組みを入れる原因になった 55 行とは桁が違う。
#
# Why not: もっと小さくしない。上の実測で最長は 278 文字で、余白は約 120 文字しかない。
#          hook の定型文を1文足しただけで切り詰めが起き、FIX の手順が消える。
# Why not: もっと大きくしない。承認ダイアログが画面外へ出ないことが目的なので、
#          可変部分の抜粋が壊れたときに気づける位置に置いておく。
: "${HOOK_DECISION_MAX_CHARS:=400}"
# 理由文へ埋め込む入力（コマンド・パス・パッケージ一覧）の抜粋の上限（文字数）。
# 長さに上限のない入力は、埋め込む前に必ずこの関数へ通す。通し忘れると理由文の
# 長さが判定対象の入力で決まってしまい、上限 400 が最後の砦として働くことになる。
: "${HOOK_EXCERPT_MAX_CHARS:=120}"

# hook_emit_decision <deny|ask> <PreToolUse|PostToolUse> <message>
# JSON を標準出力へ書く。exit は呼び出し側が行う（hook ごとに終了コードが違うため）。
hook_emit_decision() {
  jq -n \
    --arg decision "$1" \
    --arg event "$2" \
    --arg msg "$3" \
    --argjson max "$HOOK_DECISION_MAX_CHARS" '
    "…（以下省略）" as $suffix
    | ($msg | gsub("\\s+"; " ") | sub("^ +"; "") | sub(" +$"; "")) as $flat
    | (if ($flat | length) > $max
       then ($flat[:($max - ($suffix | length))] + $suffix)
       else $flat end) as $reason
    | {hookSpecificOutput: {
        hookEventName: $event,
        permissionDecision: $decision,
        permissionDecisionReason: $reason
      }}'
}

# hook_excerpt <text>
# 理由文へ埋め込む入力を、1行かつ上限内の抜粋にして標準出力へ書く。
# 全文が要らないのは、どのコマンドが止まったかは先頭で識別でき、何のルールに
# 一致したかは理由文の label がすでに示しているため。
hook_excerpt() {
  jq -rn \
    --arg s "$1" \
    --argjson max "$HOOK_EXCERPT_MAX_CHARS" '
    ($s | gsub("\\s+"; " ") | sub("^ +"; "") | sub(" +$"; "")) as $flat
    | ("…（全" + (($flat | length) | tostring) + "文字）") as $suffix
    | if ($flat | length) > $max
      then ($flat[:($max - ($suffix | length))] + $suffix)
      else $flat end'
}
