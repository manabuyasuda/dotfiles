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

# 詳細ログを表示しながら実行
gh clean-branches --verbose

# 未プッシュの変更があるブランチも強制削除
gh clean-branches --force
```

## 主要オプション

| オプション | 説明 |
|---|---|
| `--dry-run` | 削除対象の一覧を表示するだけで、実際には削除しない |
| `--force` | `git branch -D`で強制削除（未プッシュの変更があっても削除される） |
| `--verbose` | リモート・ローカルブランチの一覧など詳細ログを表示 |

## 動作フロー

1. リポジトリをfetch
2. デフォルトブランチ（main等）にcheckoutしてpull
3. リモートブランチが存在しないローカルブランチを特定
4. 対象ブランチを削除（`--dry-run`時はスキップ）
5. 実行前のブランチに復帰（削除された場合はデフォルトブランチに留まる）

## ユースケース

### 削除前に対象を確認する

```bash
gh clean-branches --dry-run
```

実際に削除せず、対象ブランチの一覧のみ表示する。初回実行時や不安な場合はまずこちらで確認する。

### 不要なブランチを一括クリーンアップする

```bash
gh clean-branches
```

リモートですでに削除されたブランチのローカルコピーをまとめて削除する。`git branch -d`で削除するため、未マージの変更があるブランチは残る。

### 詳細ログで削除判定の根拠を確認する

```bash
gh clean-branches --verbose --dry-run
```

リモート・ローカルの全ブランチ一覧と削除対象を表示する。なぜ特定のブランチが削除対象になるか（ならないか）を確認したい場合に使う。

### 未プッシュの変更も含めて強制削除する

```bash
gh clean-branches --force
```

`git branch -D`による強制削除。未プッシュの変更があるブランチも削除されるので、意図的にクリーンアップしたい場合にのみ使う。

## gh-poiとの使い分け

- **gh-poi**: GitHub PRのマージ状態を基に判定。squashマージ・リベースマージに対応
- **gh-clean-branches**: リモートブランチの存在有無を基に判定。PRを使わないワークフローでも有効

## 参考リンク

- [GitHub - davidraviv/gh-clean-branches](https://github.com/davidraviv/gh-clean-branches)
