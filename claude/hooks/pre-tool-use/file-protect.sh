#!/usr/bin/env bash
# =============================================================================
# pre-tool-use/file-protect.sh — 機密ファイル・lock files への直接編集をブロック
# =============================================================================
# フック  : PreToolUse（Edit / MultiEdit / Write）
# 役割   : エージェントが誤って機密情報や依存関係の整合性を壊さないよう、
#          特定のファイルパターンへの直接書き込みを阻止する。
#
#   保護対象カテゴリ:
#     1. 環境変数・認証情報 (.env, .npmrc, .netrc など)
#        → 秘密情報が漏洩・破損するリスク
#     2. 秘密鍵・証明書 (.pem, .key, .p12 など)
#        → 認証基盤が壊れるリスク
#     3. Git 内部ファイル (.git/ 以下)
#        → リポジトリ自体が破損するリスク
#     4. 言語別 lock files (package-lock.json, yarn.lock, Cargo.lock など)
#        → 直接編集すると依存関係の整合性が壊れる。
#          パッケージマネージャー経由での更新が正しい手順。
#          ※ post-tool-use/install.sh が `npm install` を Bash 経由で実行するため
#            このガードとは干渉しない（Write ツールを使わないから）。
#     5. Terraform 状態ファイル (.tfstate, .tfvars)
#        → インフラ状態が破損するリスク
#
# 入力 : stdin の JSON（tool_input.file_path または tool_input.path）
# 出力 : stdout の JSON（permissionDecision: "deny"）
# =============================================================================

INPUT=$(cat)
# MultiEdit は file_path、Write は path を使う場合があるため両方を試みる
file=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // ""')

_deny() {
  jq -n --arg msg "$1" \
    '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":$msg}}'
  exit 0
}

# 環境変数・設定（秘密情報含む）
if echo "$file" | grep -qE '(^|/)\.env$|(^|/)\.env\.|(^|/)\.npmrc$|(^|/)\.netrc$'; then
  _deny "ERROR: $file は環境変数・認証情報を含む機密ファイルです。直接編集すると秘密情報が漏洩または破損する可能性があります。エディタで手動編集してください。"
fi

# 鍵・証明書
if echo "$file" | grep -qE '\.(pem|key|p12|pfx|cert|crt)$'; then
  _deny "ERROR: $file は秘密鍵または証明書ファイルです。直接編集すると認証が破損します。手動で管理してください。"
fi

# Git 内部
if echo "$file" | grep -qE '(^|/)\.git/'; then
  _deny "ERROR: $file は Git の内部ファイルです。直接編集すると git リポジトリが破損します。git コマンドを使用してください。"
fi

# lock files（JS/TS）
if echo "$file" | grep -qE 'package-lock\.json$|yarn\.lock$|pnpm-lock\.yaml$|bun\.lock'; then
  _deny "ERROR: $file は lock file です。直接編集すると依存関係の整合性が壊れます。パッケージマネージャー（npm/yarn/pnpm/bun）経由で更新してください。"
fi

# lock files（Python）
if echo "$file" | grep -qE 'Pipfile\.lock$|poetry\.lock$'; then
  _deny "ERROR: $file は Python の lock file です。直接編集すると依存関係の整合性が壊れます。pip/poetry 経由で更新してください。"
fi

# lock files（Ruby / PHP / Go / Rust）
if echo "$file" | grep -qE 'Gemfile\.lock$|composer\.lock$|go\.sum$|Cargo\.lock$'; then
  _deny "ERROR: $file は lock file です。直接編集すると依存関係の整合性が壊れます。各パッケージマネージャー経由で更新してください。"
fi

# Terraform 状態・変数
if echo "$file" | grep -qE '\.tfstate$|\.tfstate\.|\.tfvars$'; then
  _deny "ERROR: $file は Terraform の状態ファイルまたは変数ファイルです。直接編集するとインフラ状態が破損します。terraform コマンドを使用してください。"
fi

exit 0
