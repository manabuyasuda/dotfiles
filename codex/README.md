# Codex（dotfiles）

運用手順はリポジトリ直下の [README.md](../README.md) を参照してください。

## フック実装

判定ロジックの本体は `claude/hooks/` です。Codexは `codex/hooks/wrap/` 経由で呼び出します（SessionStart / PostToolUseはCodexのJSON形式へ変換）。

PreToolUseはClaude Codeと同じ `hookSpecificOutput` 形式のため、ラッパはstdinを渡すだけです。
