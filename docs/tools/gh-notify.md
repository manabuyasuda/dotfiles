# gh-notify

コマンドラインからGitHubの通知を表示・管理するgh拡張機能。fzfがあればインタラクティブに操作でき、通知の既読化・ブラウザで開く・diff表示などをキーバインドで実行できる。

## インストール

```bash
gh extension install meiji163/gh-notify
```

`gh/extensions` で自動インストールされる。

## 基本的な使い方

```bash
# 未読の通知を一覧表示
gh notify

# すべての通知をプレビュー付きで表示
gh notify -a -w

# 特定リポジトリの通知のみ表示
gh notify -f "repo-name"

# 参加/メンションされた通知のみ表示
gh notify -p
```

## fzf使用時の主要キーバインド

| キー | 操作 |
|------|------|
| `Enter` | 通知をlessで表示 |
| `Ctrl-B` | ブラウザで開く |
| `Ctrl-D` | diff を表示 |
| `Ctrl-T` | 選択した通知を既読にする |
| `Ctrl-A` | すべての通知を既読にする |

## ユースケース

### 未読通知を素早く確認する

```bash
gh notify -w
```

プレビューウィンドウ付きで未読通知を一覧表示し、fzfで絞り込みながら内容を確認できる。

### すべての通知を既読にする

```bash
gh notify -r
```

溜まった通知を一括で既読にする。

## 参考リンク

- [GitHub - meiji163/gh-notify](https://github.com/meiji163/gh-notify)
