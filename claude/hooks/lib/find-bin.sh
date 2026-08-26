#!/usr/bin/env bash
# =============================================================================
# lib/find-bin.sh — ツール実体の探索（共有関数）
# =============================================================================
# 実体が見つからないツールは実行しない（ツール実在ゲート）。
# Why not: `npx <tool>` にフォールバックすると、未導入のパッケージをレジストリから
#          取得しにいく（`npx tsc` は無関係な tsc パッケージに解決する）ため、
#          環境に無いツールが処理へ混ざる。実体の有無で決めれば構造的に起こらない。
# 実行権限: 不要（source されるだけで直接実行しない）
# =============================================================================

# find_local_bin <file> <tool>
#   <file> のディレクトリから上へ向かって node_modules/.bin/<tool> を探す。
#   見つかれば絶対パスを stdout に出して 0、無ければ何も出さず 1 を返す。
find_local_bin() {
  local file="$1" tool="$2" dir
  dir="$(cd "$(dirname "$file")" 2>/dev/null && pwd)" || return 1
  while [ "$dir" != "/" ] && [ -n "$dir" ]; do
    if [ -x "$dir/node_modules/.bin/$tool" ]; then
      echo "$dir/node_modules/.bin/$tool"
      return 0
    fi
    dir="$(dirname "$dir")"
  done
  return 1
}

# find_bin <file> <tool>
#   ローカル（node_modules/.bin）→ PATH の順に実体を探す。どちらにも無ければ 1 を返す。
find_bin() {
  local file="$1" tool="$2" found
  if found=$(find_local_bin "$file" "$tool"); then
    echo "$found"
    return 0
  fi
  command -v "$tool" 2>/dev/null && return 0
  return 1
}
