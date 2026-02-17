# gh-dash

ターミナル上でPRやIssueを一覧管理できるリッチなTUIダッシュボード。リポジトリごとにセクションをカスタマイズでき、diff表示・コメント・チェックアウトなどの操作をダッシュボード内で完結できる。

## インストール

```bash
gh extension install dlvhdr/gh-dash
```

`gh/extensions` で自動インストールされる。

## 基本的な使い方

```bash
# ダッシュボードを起動
gh dash

# 設定ファイルを指定して起動
gh dash -c path/to/config.yml
```

## ダッシュボード内の主要キーバインド

| キー | 操作 |
|------|------|
| `?` | キーバインド一覧を表示 |
| `j`/`k` | 上下移動 |
| `Enter` | PR/Issueの詳細を表示 |
| `d` | diff を表示 |
| `c` | チェックアウト |

## ユースケース

### 複数リポジトリのPRを一括管理する

```bash
gh dash
```

設定ファイル(`~/.config/gh-dash/config.yml`)でリポジトリやフィルタを定義すれば、複数リポジトリのPR・Issueをひとつのダッシュボードで確認できる。

### レビュー待ちPRを素早く確認する

ダッシュボードを起動し、PRセクションからレビュー依頼されたPRを確認。diff表示やチェックアウトもその場で実行できる。

## 参考リンク

- [GitHub - dlvhdr/gh-dash](https://github.com/dlvhdr/gh-dash)
