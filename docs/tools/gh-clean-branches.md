# gh-clean-branches

リモートブランチが存在せず、未プッシュの変更もないローカルブランチを安全に削除するgh拡張機能。fetch後にデフォルトブランチへcheckout・pullし、削除対象を特定してから削除、元のブランチに戻るという流れで動作する。

## インストール

```bash
gh extension install davidraviv/gh-clean-branches
```

`gh/extensions` で自動インストールされる。

## 基本的な使い方

```bash
# 不要なローカルブランチを検出・削除
gh clean-branches

# ドライラン（削除対象を確認するだけ）
gh clean-branches --dry-run

# 未マージの変更があるブランチも強制削除
gh clean-branches --force
```

## ユースケース

### 削除前に対象を確認する

```bash
gh clean-branches --dry-run
```

実際に削除せず、対象ブランチの一覧のみ表示する。

### 不要なブランチを一括クリーンアップする

```bash
gh clean-branches
```

リモートで既に削除されたブランチのローカルコピーをまとめて削除する。

## gh-poiとの使い分け

- **gh-poi**: GitHub PRのマージ状態を基に判定。squashマージ・リベースマージに対応
- **gh-clean-branches**: リモートブランチの存在有無を基に判定。PRを使わないワークフローでも有効

## 参考リンク

- [GitHub - davidraviv/gh-clean-branches](https://github.com/davidraviv/gh-clean-branches)
