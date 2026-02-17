# ripgrep

grep の高速な代替ツール。Rust製で、デフォルトで`.gitignore`を尊重し、バイナリファイルをスキップし、再帰検索を行う。`grep -r`と比較して数倍〜数十倍速いケースもあり、大規模リポジトリでの検索体験が劇的に変わる。

## インストール

```bash
brew install ripgrep
```

`Brewfile` で管理。コマンド名は `rg`。

## 基本的な使い方

```bash
# カレントディレクトリ以下を再帰検索
rg "useState"

# ファイルタイプを指定して検索
rg "useState" --type ts

# 大文字小文字を無視
rg -i "error"

# ファイル名のみ表示
rg -l "TODO"

# 正規表現で検索
rg "function\s+\w+"
```

## ユースケース

### TypeScriptプロジェクトで特定のパターンを検索する

```bash
rg "useState" --type ts
```

`.ts`/`.tsx`ファイルのみを対象に高速検索する。`--type`で言語を指定すると、対応する拡張子を自動で判別する。

### TODO/FIXMEを一覧する

```bash
rg "TODO|FIXME|HACK" --type ts
```

プロジェクト内に残っている技術的負債のマーカーを洗い出す。

### JSON出力で他ツールと連携する

```bash
rg "pattern" --json
```

`--json`出力で構造化されたデータとして取得し、他のツールやスクリプトに渡せる。

## 参考リンク

- [GitHub - BurntSushi/ripgrep](https://github.com/BurntSushi/ripgrep)
