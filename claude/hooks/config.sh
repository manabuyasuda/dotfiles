#!/usr/bin/env bash
# =============================================================================
# config.sh — 保護ブランチ定義（共有設定）
# =============================================================================
# 用途   : pre-tool-use/branch-guard.sh と pre-tool-use/bash-guard.sh が
#          `source` して使う共有設定。
#          PROTECTED_BRANCHES 配列を一元管理し、2ファイルで定義を重複させない。
# 実行権限: 不要（source されるだけで直接実行しない）
# 参照元 : pre-tool-use/branch-guard.sh（Edit/Write の保護ブランチチェック）
#          pre-tool-use/bash-guard.sh（git merge の保護ブランチチェック）
#
# パターン仕様:
#   bash の [[ == ]] 演算子による glob マッチを使用する。
#   "release/*" のようなパターンはクォートが必要（シェル展開を防ぐため）。
# =============================================================================

# 保護ブランチ（直接編集・ローカルマージを禁止）（glob パターン可）
PROTECTED_BRANCHES=(
  # デフォルトブランチ
  main
  master
  # Gitflow
  develop
  development
  "release/*"
  "hotfix/*"
  # 環境ブランチ
  staging
  production
  prod
  # プレビュー・段階ロールアウト
  "preview/*"
  canary
  beta
  # その他
  gh-pages
  "dependabot/*"
)
