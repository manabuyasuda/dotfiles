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

## 主要オプション

| フラグ | 説明 |
|--------|------|
| `-l, --lang` | プログラミング言語で絞り込み（複数指定可） |
| `-u, --user` | 特定ユーザー/組織に限定 |
| `-d, --desc` | 説明文から検索 |
| `-t, --topic` | トピックで絞り込み（複数指定可） |
| `-L, --limit` | 表示件数を制限（デフォルト: 20） |
| `-E, --empty` | 名前なし検索を許可（トピックや言語のみで検索） |
| `-c, --colour` | プロンプトの色を変更 |

## プロンプト操作

| キー | 動作 |
|------|------|
| 矢印キー（上下） | 候補を移動 |
| `/` | あいまい検索の切り替え |
| Enter | 選択したリポジトリのURLを標準出力に返す |

## ユースケース

### 特定言語のライブラリを探す

```bash
gh s markdown-parser -l rust
```

Rust製のMarkdownパーサーをインタラクティブに検索する。

### 複数言語で横断検索する

```bash
gh s http-client -l go -l rust
```

`-l`を複数指定して、GoとRust両方のHTTPクライアントを一度に検索する。

### トピックのみで検索する

```bash
gh s -E -t cli -t golang
```

`-E`フラグでリポジトリ名を空にし、トピックだけで検索する。特定の技術領域を広く探索したいときに便利。

### 検索結果をパイプでクローンする

```bash
gh s fzf | xargs gh repo clone
```

検索で選択したリポジトリのURLがそのまま標準出力に渡されるため、パイプでクローンまで一気に実行できる。

## 参考リンク

- [GitHub - gennaro-tedesco/gh-s](https://github.com/gennaro-tedesco/gh-s)
