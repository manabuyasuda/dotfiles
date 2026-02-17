# fd

find コマンドの現代的な代替ツール。Rust製で、デフォルトで`.gitignore`を尊重し、正規表現ベースのマッチングをする。出力もカラー付きで見やすく、`find`の冗長な記法が不要になる。

## インストール

```bash
brew install fd
```

`Brewfile` で管理。

## 基本的な使い方

```bash
# ファイル名であいまい検索
fd readme

# 正規表現で検索
fd "\.test\.ts$"

# 拡張子で絞り込み
fd -e tsx

# ディレクトリのみ検索
fd --type d

# 隠しファイルも含めて検索
fd -H "\.env"
```

## ユースケース

### テストファイルを一覧する

```bash
fd "\.test\.ts$"
```

`find . -name "*.test.ts"` と同等だが、より簡潔で高速。

### 特定の拡張子のファイルに一括処理を実行する

```bash
fd -e tsx -x prettier -w
```

全`.tsx`ファイルを見つけて、それぞれに`prettier`を実行する。`-x`で各ファイルに対してコマンドを実行できる。

### fzf と組み合わせてインタラクティブに検索する

```bash
fd --type f | fzf
```

fd の高速なファイル列挙と fzf のあいまい検索を組み合わせた、強力なファイル検索ワークフロー。

## 参考リンク

- [GitHub - sharkdp/fd](https://github.com/sharkdp/fd)
