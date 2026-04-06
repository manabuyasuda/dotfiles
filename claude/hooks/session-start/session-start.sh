#!/usr/bin/env bash
# =============================================================================
# session-start.sh — セッション開始時の環境検証とコンテキスト提供
# =============================================================================
# フック  : SessionStart（セッション開始時に1回だけ実行）
# 役割   : エージェントが作業を始める前に現在の環境状態を把握させる。
#          3つの情報を提供する:
#            1. 開発ツールの検出（フォーマッター・リンター・テストランナーなど）
#            2. $CLAUDE_ENV_FILE への環境変数の書き出し（後続フックが参照）
#            3. git の現在状態（ブランチ・直近コミット・未コミット変更）
#
# 出力:
#   stdout   → Claude のコンテキストに注入される（エージェントが読む）
#   $CLAUDE_ENV_FILE → 後続フック（post-tool-use/format.sh 等）が source して使う環境変数ファイル
#
# 終了コード: 常に 0（ブロックしない。情報提供のみ）
#
# ツール検出の優先順位:
#   ローカル（node_modules/.bin/）→ グローバル（PATH）の順で検索する。
#   プロジェクトローカルのツールを優先することで、グローバルバージョンとの
#   食い違いを防ぐ。
# =============================================================================

# $CLAUDE_ENV_FILE が設定されている場合のみ環境変数を書き出す。
# 未設定時はスキップ（後続フックに渡す変数がないだけで動作には影響しない）。
_env() { [ -n "$CLAUDE_ENV_FILE" ] && echo "$1" >> "$CLAUDE_ENV_FILE"; }

# ツールをローカル → グローバルの順で検索し、見つかった場所（"local"/"global"）を返す。
# 見つからない場合は空文字を返す。
_find_tool() {
  if [ -x "node_modules/.bin/$1" ]; then echo "local"
  elif command -v "$1" &>/dev/null; then echo "global"
  else echo ""
  fi
}

echo "=== 環境・プロジェクト設定 ==="

# Node.js
if command -v node &>/dev/null; then
  echo "Node: $(node --version)"
  _env "export NODE_AVAILABLE=true"
else
  echo "WARNING: Node.js が見つかりません"
  _env "export NODE_AVAILABLE=false"
fi

# パッケージマネージャー（packageManager フィールド → lock file の優先順で検出）
pkg_mgr=""
if command -v node &>/dev/null && [ -f "package.json" ]; then
  pkg_mgr=$(node -e "try{const p=require('./package.json');console.log((p.packageManager||'').split('@')[0])}catch(e){}" 2>/dev/null)
fi
if [ -z "$pkg_mgr" ]; then
  if   [ -f "pnpm-lock.yaml" ];                   then pkg_mgr="pnpm"
  elif [ -f "yarn.lock" ];                         then pkg_mgr="yarn"
  elif [ -f "bun.lockb" ] || [ -f "bun.lock" ];   then pkg_mgr="bun"
  else pkg_mgr="npm"
  fi
fi
case "$pkg_mgr" in
  pnpm) echo "Package manager: pnpm $(pnpm --version 2>/dev/null || echo '(unknown)')" ;;
  yarn) echo "Package manager: yarn $(yarn --version 2>/dev/null || echo '(unknown)')" ;;
  bun)  echo "Package manager: bun $(bun --version 2>/dev/null || echo '(unknown)')"  ;;
  *)    echo "Package manager: npm $(npm --version 2>/dev/null || echo '(unknown)')"  ; pkg_mgr="npm" ;;
esac
_env "export PKG_MANAGER=$pkg_mgr"

# gh CLI
if gh auth status &>/dev/null; then
  _env "export GH_AUTH=true"
else
  echo "WARNING: gh CLI が未認証です。gh auth login を実行してください"
  _env "export GH_AUTH=false"
fi

# フォーマッター（biome は lint も兼ねるため優先）
if [ -n "$(_find_tool biome)" ]; then
  echo "Formatter: biome ($(_find_tool biome))"
  _env "export FORMATTER=biome"
elif [ -n "$(_find_tool prettier)" ]; then
  echo "Formatter: prettier ($(_find_tool prettier))"
  _env "export FORMATTER=prettier"
else
  echo "Formatter: (not found)"
  _env "export FORMATTER=none"
fi

# リンター
if [ -n "$(_find_tool biome)" ]; then
  echo "Linter: biome ($(_find_tool biome))"
  _env "export LINTER=biome"
elif [ -n "$(_find_tool eslint)" ]; then
  echo "Linter: eslint ($(_find_tool eslint))"
  _env "export LINTER=eslint"
else
  echo "Linter: (not found)"
  _env "export LINTER=none"
fi

# マークアップ・CSS リンター
if [ -n "$(_find_tool markuplint)" ]; then
  echo "Markuplint: yes ($(_find_tool markuplint))"; _env "export MARKUPLINT=true"
else
  _env "export MARKUPLINT=false"
fi
if [ -n "$(_find_tool stylelint)" ]; then
  echo "Stylelint: yes ($(_find_tool stylelint))"; _env "export STYLELINT=true"
else
  _env "export STYLELINT=false"
fi

# テストランナー
if [ -n "$(_find_tool vitest)" ]; then
  echo "Test runner: vitest ($(_find_tool vitest))"; _env "export TEST_RUNNER=vitest"
elif [ -n "$(_find_tool jest)" ]; then
  echo "Test runner: jest ($(_find_tool jest))"; _env "export TEST_RUNNER=jest"
else
  echo "Test runner: (not found)"; _env "export TEST_RUNNER=none"
fi

# テストユーティリティ
test_tools=""
if [ -d "node_modules/@testing-library" ];                                        then test_tools="${test_tools} @testing-library"; _env "export TESTING_LIBRARY=true";  else _env "export TESTING_LIBRARY=false"; fi
if [ -d "node_modules/@playwright/test" ] || [ -x "node_modules/.bin/playwright" ]; then test_tools="${test_tools} playwright";     _env "export PLAYWRIGHT=true";       else _env "export PLAYWRIGHT=false";      fi
if [ -d "node_modules/msw" ];                                                     then test_tools="${test_tools} msw";             _env "export MSW=true";              else _env "export MSW=false";            fi
if [ -d "node_modules/@storybook/core" ] || [ -d "node_modules/storybook" ] || [ -d ".storybook" ]; then test_tools="${test_tools} storybook"; _env "export STORYBOOK=true"; else _env "export STORYBOOK=false"; fi
if [ -d "node_modules/cypress" ] || [ -x "node_modules/.bin/cypress" ];           then test_tools="${test_tools} cypress";         _env "export CYPRESS=true";          else _env "export CYPRESS=false";        fi
if [ -d "node_modules/axe-core" ] || [ -d "node_modules/jest-axe" ];              then test_tools="${test_tools} axe";             _env "export AXE=true";              else _env "export AXE=false";            fi
[ -n "$test_tools" ] && echo "Test utilities:${test_tools}"

# TypeScript
if [ -f "tsconfig.json" ]; then
  echo "TypeScript: yes"; _env "export TYPESCRIPT=true"
else
  echo "TypeScript: no";  _env "export TYPESCRIPT=false"
fi

# モノレポ
monorepo="none"
if   [ -f "pnpm-workspace.yaml" ]; then monorepo="pnpm-workspaces"
elif [ -f "turbo.json" ];           then monorepo="turborepo"
elif [ -f "lerna.json" ];           then monorepo="lerna"
elif command -v node &>/dev/null && [ -f "package.json" ]; then
  has_ws=$(node -e "try{const p=require('./package.json');console.log(!!p.workspaces)}catch(e){console.log(false)}" 2>/dev/null)
  [ "$has_ws" = "true" ] && monorepo="yarn-workspaces"
fi
[ "$monorepo" != "none" ] && echo "Monorepo: $monorepo"
_env "export MONOREPO=$monorepo"

# コード品質・解析ツール
quality_tools=""
if [ -n "$(_find_tool react-doctor)" ];  then quality_tools="${quality_tools} react-doctor";       _env "export REACT_DOCTOR=true";  else _env "export REACT_DOCTOR=false";  fi
if [ -n "$(_find_tool depcruise)" ];     then quality_tools="${quality_tools} dependency-cruiser"; _env "export DEPCRUISER=true";    else _env "export DEPCRUISER=false";    fi
if [ -n "$(_find_tool type-coverage)" ]; then quality_tools="${quality_tools} type-coverage";      _env "export TYPE_COVERAGE=true"; else _env "export TYPE_COVERAGE=false"; fi
if [ -n "$(_find_tool lhci)" ];          then quality_tools="${quality_tools} lighthouse-ci";      _env "export LIGHTHOUSE_CI=true"; else _env "export LIGHTHOUSE_CI=false"; fi
if [ -n "$(_find_tool semgrep)" ];       then quality_tools="${quality_tools} semgrep";            _env "export SEMGREP=true";       else _env "export SEMGREP=false";       fi
if [ -n "$(_find_tool socket)" ];        then quality_tools="${quality_tools} socket";             _env "export SOCKET=true";        else _env "export SOCKET=false";        fi
[ -n "$quality_tools" ] && echo "Quality tools:${quality_tools}"

# --- セッション復帰コンテキスト ---
BRANCH=$(git branch --show-current 2>/dev/null) || BRANCH=""
if [ -z "$BRANCH" ]; then
  echo "WARNING: detached HEAD 状態です。ブランチを作成してから作業してください"
else
  echo ""
  echo "ブランチ: ${BRANCH}"
fi

echo ""
echo "=== 直近のコミット ==="
git log --oneline -5 2>/dev/null || echo "(git リポジトリではありません)"

UNCOMMITTED=$(git status --porcelain 2>/dev/null | head -5)
if [ -n "$UNCOMMITTED" ]; then
  echo ""
  echo "=== 未コミット変更あり ==="
  echo "$UNCOMMITTED"
fi

exit 0
