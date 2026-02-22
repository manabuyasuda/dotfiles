#!/bin/bash
# macOSのシステム設定を自動適用するスクリプト
# 実行後はログアウトまたは再起動が必要な場合がある

set -euo pipefail

echo "=== macOS設定を適用中 ==="

# =========================================
# 一般
# =========================================

# スクロールバーを常に表示
defaults write NSGlobalDomain AppleShowScrollBars -string "Always"

# スクリーンショットの保存先を書類/Screenshotに変更
mkdir -p ~/Documents/Screenshot
defaults write com.apple.screencapture location ~/Documents/Screenshot

# 書類を閉じるときに変更内容を保持するかどうかを確認
defaults write NSGlobalDomain NSCloseAlwaysConfirmsChanges -bool true

# =========================================
# デスクトップとDock
# =========================================

# Dockのサイズ（25%程度）
defaults write com.apple.dock tilesize -int 36

# Dockの位置を左に
defaults write com.apple.dock orientation -string "left"

# ウィンドウタイトルバーのダブルクリックでしまう
defaults write NSGlobalDomain AppleActionOnDoubleClick -string "Minimize"

# Dockを自動的に表示／非表示
defaults write com.apple.dock autohide -bool true

# 起動中のアプリケーションをアニメーションで表示しない
defaults write com.apple.dock launchanim -bool false

# =========================================
# ロック画面
# =========================================

# スクリーンセーバーを5分後に開始
defaults -currentHost write com.apple.screensaver idleTime -int 300

# スクリーンセーバー解除にパスワードをすぐに要求
defaults write com.apple.screensaver askForPassword -int 1
defaults write com.apple.screensaver askForPasswordDelay -int 0

# =========================================
# キーボード
# =========================================

# キーのリピートを最速に
defaults write NSGlobalDomain KeyRepeat -int 2

# リピート入力認識までの時間を最速に
defaults write NSGlobalDomain InitialKeyRepeat -int 15

# 英字入力中にスペルを自動変換しない
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false

# 文頭を自動的に大文字にしない
defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false

# スペースバーを2回押してピリオドを入力しない
defaults write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false

# スマート引用符を使用しない
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false

# スマートダッシュを使用しない
defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false

# =========================================
# 反映
# =========================================

killall Dock 2>/dev/null || true

echo ""
echo "=== 完了 ==="
echo "一部の設定はログアウトまたは再起動後に反映される"
