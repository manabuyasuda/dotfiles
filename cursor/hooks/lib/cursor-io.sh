#!/usr/bin/env bash
# =============================================================================
# cursor-io.sh — Claude Code フック I/O と Cursor フック I/O の変換ヘルパ
# =============================================================================
# Cursor の beforeShellExecution / preToolUse 用アダプタから source する。
# 判定ロジックは claude/hooks/ に置き、ここでは入出力形式の変換だけを担う。
# =============================================================================

# lib ディレクトリは source 時に固定する（関数内の BASH_SOURCE[0] は呼び出し元になる）
_CURSOR_IO_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

# dotfiles リポジトリのルート（cursor/hooks/lib から 3 階層上）
cursor_io_dotfiles_dir() {
  (cd "$_CURSOR_IO_LIB_DIR/../../.." && pwd -P)
}
# claude フックが見つからないときはフェイルオープン（設定ミスでエージェント全体を止めない）
cursor_io_fail_open_missing_hook() {
  local label="$1" hook_path="$2"
  echo "${label}: hook not found: ${hook_path} (fail open)" >&2
  cursor_io_allow
}

# claude/hooks/pre-tool-use/<name> の絶対パス
cursor_io_claude_pre_tool_use_hook() {
  local name="$1"
  echo "$(cursor_io_dotfiles_dir)/claude/hooks/pre-tool-use/$name"
}

# Cursor beforeShellExecution / preToolUse(Shell) JSON → Claude PreToolUse(Bash) JSON
# beforeShellExecution は command のみ。description は preToolUse(Shell) の tool_input に入る。
cursor_io_shell_to_claude_json() {
  jq '{
    tool_input: {
      command: (.tool_input.command // .command // ""),
      description: (.tool_input.description // .description // "")
    },
    cwd: (.cwd // .workspace.current_dir // .tool_input.working_directory // "")
  }'
}

# Cursor preToolUse(Write) JSON → Claude PreToolUse(Edit|Write) JSON
cursor_io_write_to_claude_json() {
  jq '{
    tool_name: (.tool_name // "Write"),
    agent_id: (.agent_id // .subagent_id // ""),
    tool_input: {
      file_path: (
        .tool_input.file_path // .tool_input.path
        // .file_path // .path // ""
      ),
      path: (
        .tool_input.path // .tool_input.file_path
        // .path // .file_path // ""
      ),
      new_string: (
        .tool_input.new_string // .new_string // ""
      ),
      content: (
        .tool_input.content // .content // ""
      )
    },
    cwd: (.cwd // .workspace.current_dir // ""),
    session_id: (.session_id // "")
  }'
}

# session-start が書き出す環境変数ファイル（CLAUDE_ENV_FILE の Cursor 版）
cursor_io_session_env_file() {
  local session_id="$1"
  echo "${HOME}/.cursor/cache/hook-env/${session_id}.env"
}

# post-tool-use フック実行前にセッション環境を読み込み、プロジェクト cwd へ移動
cursor_io_prepare_post_hook() {
  local input="$1"
  local session_id cwd env_file

  session_id=$(printf '%s' "$input" | jq -r '.session_id // empty')
  if [[ -n "$session_id" ]]; then
    env_file="$(cursor_io_session_env_file "$session_id")"
    if [[ -f "$env_file" ]]; then
      set -a
      # shellcheck disable=SC1090
      source "$env_file"
      set +a
      export CLAUDE_ENV_FILE="$env_file"
    fi
  fi

  cwd=$(printf '%s' "$input" | jq -r '.cwd // .workspace.current_dir // empty')
  if [[ -n "$cwd" && -d "$cwd" ]]; then
    cd "$cwd" || true
  fi
}

# claude/settings.json の env をフック実行前に読み込む（Cursor は自動注入しない）
cursor_io_load_settings_env() {
  local settings
  settings="$(cursor_io_dotfiles_dir)/claude/settings.json"
  if [[ -f "$settings" ]]; then
    if [[ -z "${EXPECTED_GH_ACCOUNT:-}" ]]; then
      EXPECTED_GH_ACCOUNT=$(jq -r '.env.EXPECTED_GH_ACCOUNT // empty' "$settings")
      export EXPECTED_GH_ACCOUNT
    fi
  fi
}

# claude/hooks/post-tool-use/<name> の絶対パス
cursor_io_claude_post_tool_use_hook() {
  local name="$1"
  echo "$(cursor_io_dotfiles_dir)/claude/hooks/post-tool-use/$name"
}

# Claude PostToolUse の stdout を Cursor postToolUse 出力に変換
cursor_io_emit_claude_post_tool_use() {
  local claude_output="$1"
  local decision reason ctx

  if [ -z "$claude_output" ]; then
    exit 0
  fi

  if printf '%s' "$claude_output" | jq -e '.suppressOutput == true' >/dev/null 2>&1; then
    exit 0
  fi

  decision=$(printf '%s' "$claude_output" | jq -r '.decision // empty')
  if [ "$decision" = "block" ]; then
    reason=$(printf '%s' "$claude_output" | jq -r '.reason // empty')
    if [ -n "$reason" ]; then
      jq -n --arg ctx "$reason" '{additional_context: $ctx}'
    fi
    exit 0
  fi

  decision=$(printf '%s' "$claude_output" | jq -r '.hookSpecificOutput.permissionDecision // empty')
  reason=$(printf '%s' "$claude_output" | jq -r '.hookSpecificOutput.permissionDecisionReason // empty')
  ctx=$(printf '%s' "$claude_output" | jq -r '.hookSpecificOutput.additionalContext // empty')

  if [ "$decision" = "deny" ] && [ -n "$reason" ]; then
    jq -n --arg ctx "$reason" '{additional_context: $ctx}'
    exit 0
  fi

  if [ -n "$ctx" ]; then
    jq -n --arg ctx "$ctx" '{additional_context: $ctx}'
  fi
  exit 0
}

cursor_io_allow() {
  jq -n '{permission: "allow"}'
  exit 0
}

# Claude PreToolUse の stdout を Cursor の permission JSON に変換して出力する
cursor_io_emit_claude_pre_tool_use() {
  local claude_output="$1"
  local decision reason

  if [ -z "$claude_output" ]; then
    cursor_io_allow
  fi

  decision=$(printf '%s' "$claude_output" | jq -r '.hookSpecificOutput.permissionDecision // empty')
  reason=$(printf '%s' "$claude_output" | jq -r '.hookSpecificOutput.permissionDecisionReason // empty')

  if [ -z "$decision" ] || [ "$decision" = "null" ]; then
    cursor_io_allow
  fi

  case "$decision" in
    deny | ask)
      jq -n --arg p "$decision" --arg um "$reason" --arg am "$reason" \
        '{permission: $p, user_message: $um, agent_message: $am}'
      exit 0
      ;;
    *)
      cursor_io_allow
      ;;
  esac
}
