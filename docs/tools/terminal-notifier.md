# terminal-notifier

macOS のデスクトップ通知をターミナルから送信するツール。長時間の処理の完了通知や、Claude Code の確認待ち通知などに使える。

## インストール

```bash
brew install terminal-notifier
```

## 基本的な使い方

```bash
# シンプルな通知を送る
terminal-notifier -message "処理が完了しました"

# タイトルとメッセージを指定する
terminal-notifier -title "ビルド完了" -message "本番ビルドが成功しました"

# 通知音を付ける
terminal-notifier -message "完了" -sound Glass

# 特定のアプリのアイコンで通知を送る
terminal-notifier -message "完了" -sender com.apple.Terminal

# 通知クリックでURLを開く
terminal-notifier -message "デプロイ完了" -open "https://example.com"
```

## 主要オプション

| オプション | 説明 |
|---|---|
| `-message <text>` | 通知本文を指定する（必須） |
| `-title <text>` | 通知タイトルを指定する |
| `-subtitle <text>` | サブタイトルを指定する |
| `-sound <name>` | 通知音を指定する（例: `Glass`, `Ping`, `Basso`） |
| `-sender <bundle-id>` | 表示するアプリのアイコンを指定する |
| `-open <url>` | クリック時に開く URL を指定する |
| `-execute <cmd>` | クリック時に実行するコマンドを指定する |
| `-timeout <sec>` | 通知を自動的に閉じるまでの秒数を指定する |

## このリポジトリでの使われ方

Claude Codeの`Notification`フック（`settings.json`）で使用している。

```json
{
  "matcher": "permission_prompt",
  "hooks": [{
    "type": "command",
    "command": "terminal-notifier -title \"Claude Code\" -message '確認が必要です' -sound Glass"
  }]
}
```

| イベント | 通知内容 |
|---|---|
| `permission_prompt` | 確認が必要です |
| `idle_prompt` | 入力待ちです |
| `stop` | 処理が完了しました |

## ユースケース

### 長時間コマンドの完了を通知する

```bash
npm run build && terminal-notifier -title "ビルド" -message "成功しました" -sound Glass \
  || terminal-notifier -title "ビルド" -message "失敗しました" -sound Basso
```

## 参考リンク

- [GitHub - julienXX/terminal-notifier](https://github.com/julienXX/terminal-notifier)
