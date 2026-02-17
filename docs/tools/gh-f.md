# gh-f

fzfを活用してGitHub操作（PR、ブランチ、ログ、ワークフロー等）をインタラクティブにフィルタ・操作できるgh拡張機能。fzfが必要。

## インストール

```bash
gh extension install gennaro-tedesco/gh-f
```

`gh/extensions` で自動インストールされる。

## 基本的な使い方

```bash
# PRをfzfで一覧表示（Enter: checkout / Ctrl-D: diff / Ctrl-V: view）
gh f -p

# ブランチをfzfで一覧表示（Enter: checkout / Ctrl-D: diff / Ctrl-X: delete）
gh f -b

# コミット履歴をfzfで表示（Enter: checkout / Ctrl-D: diff）
gh f -l

# GitHub Actionsのワークフロー実行結果を表示
gh f -r

# ファイルをインタラクティブにステージング
gh f -a
```

## ユースケース

### PRをあいまい検索してチェックアウトする

```bash
gh f -p
```

fzfの絞り込みUIでPRを検索し、Enterでそのままブランチをチェックアウトできる。

### ブランチを選択して操作する

```bash
gh f -b
```

ローカル・リモートブランチをfzfで一覧表示し、チェックアウト・diff確認・削除をキーバインドで操作する。

## 参考リンク

- [GitHub - gennaro-tedesco/gh-f](https://github.com/gennaro-tedesco/gh-f)
