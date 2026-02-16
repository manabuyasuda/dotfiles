# gh-poi

マージ済みのローカルブランチを安全に一括削除する gh 拡張機能。GitHub のプルリクエスト情報をもとにマージ済みかどうかを判定するため、squash マージやリベースマージにも対応する。

## インストール

```bash
gh extension install seachicken/gh-poi
```

`gh/extensions` で自動インストールされる。

## 基本的な使い方

```bash
# マージ済みブランチを対話的に削除
gh poi

# ドライラン（削除対象を確認するだけ）
gh poi --dry-run
```

## ユースケース

### マージ済みブランチを一括クリーンアップする

```bash
gh poi
```

フィーチャーブランチが溜まったローカルリポジトリで、マージ済みのブランチをまとめて削除する。`git branch -d` と異なり、squash マージされたブランチも正しく検出できる。

### 削除前に対象を確認する

```bash
gh poi --dry-run
```

実際に削除する前に、どのブランチが対象になるかを確認する。

## 参考リンク

- [GitHub - seachicken/gh-poi](https://github.com/seachicken/gh-poi)
