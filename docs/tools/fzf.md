# fzf

汎用のあいまい検索ツール。標準入力から受け取った任意のリストに対して、インタラクティブに絞り込み検索ができる。fzf自体は「検索UI」であり、何を検索するかはパイプで渡す側が決める設計のため、あらゆるCLIワークフローに組み込める。

## インストール

```bash
brew install fzf
```

`Brewfile` で管理。

## 基本的な使い方

```bash
# コマンド履歴をあいまい検索（Ctrl+R）
# ※ fzfインストール後、シェルに自動統合される

# ファイルをインタラクティブに検索
find . | fzf

# ブランチを選択
git branch | fzf

# プレビュー付きでファイルを検索
fzf --preview 'cat {}'
```

## ユースケース

### fd と組み合わせてファイルを高速検索する

```bash
fd --type f | fzf
```

fd の高速なファイル列挙と fzf のインタラクティブな絞り込みを組み合わせて、大規模プロジェクトでも快適にファイルを探せる。

### プレビュー付きでファイルを選択する

```bash
fzf --preview 'bat --color=always {}'
```

ファイル選択時にシンタックスハイライト付きのプレビューを表示する。`bat` の代わりに `cat` でも可。

### git ブランチを選択してチェックアウトする

```bash
git branch | fzf | xargs git checkout
```

ブランチ名をあいまい検索で絞り込み、そのままチェックアウトできる。

## 参考リンク

- [GitHub - junegunn/fzf](https://github.com/junegunn/fzf)
