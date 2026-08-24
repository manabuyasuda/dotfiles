#!/usr/bin/env bash
# =============================================================================
# lib/cursor-compat.sh — Cursor 互換実行の検出（共有関数）
# =============================================================================
# Cursor CLI は cursor/hooks.json のアダプタに加えて、~/.claude/settings.json に
# 登録された Claude Code 互換フックも直接実行する（二重実行）。
# 同じ guard はアダプタ側で実行済みのため、互換実行側では判定せず通過する。
# Why not: メッセージが "---" 連結で二重に届き、preToolUse の ask は
#          ダイアログにならないため、互換実行側の判定は挙動を歪めるだけになる。
# Cursor のペイロードだけが持つ cursor_version キーで決定論的に識別する。
# 実行権限: 不要（source されるだけで直接実行しない）
# =============================================================================

exit_if_cursor_payload() {
  if printf '%s' "$1" | jq -e '.cursor_version' >/dev/null 2>&1; then
    exit 0
  fi
  return 0
}
