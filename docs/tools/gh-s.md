# gh-s

コマンドラインからGitHubリポジトリをインタラクティブに検索するgh拡張機能。言語・ユーザー・トピックなどで絞り込みができ、選択したリポジトリのURLを標準出力に出力するためパイプでの連携も可能。

## インストール

```bash
gh extension install gennaro-tedesco/gh-s
```

`gh/extensions` で自動インストールされる。

## 基本的な使い方

```bash
# 対話的にリポジトリを検索
gh s

# キーワードと言語で絞り込み
gh s neovim -l go

# ユーザーとトピックで絞り込み
gh s lsp -u neovim -t plugin
```

## 主なオプション

| フラグ | 説明 |
|--------|------|
| `-l, --lang` | プログラミング言語で絞り込み |
| `-u, --user` | 特定ユーザー/組織に限定 |
| `-d, --desc` | 説明文から検索 |
| `-t, --topic` | トピックで絞り込み |
| `-L, --limit` | 表示件数を制限（デフォルト: 20） |

## ユースケース

### 特定言語のライブラリを探す

```bash
gh s markdown-parser -l rust
```

Rust製のMarkdownパーサーをインタラクティブに検索し、選択したリポジトリをブラウザで開ける。

### 検索結果をパイプで連携する

```bash
gh s fzf | xargs gh repo clone
```

検索で選択したリポジトリをそのままクローンする。

## 参考リンク

- [GitHub - gennaro-tedesco/gh-s](https://github.com/gennaro-tedesco/gh-s)
