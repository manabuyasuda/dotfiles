# wtp (Worktree Plus)

`git worktree` を拡張した CLI ツール。`.wtp.yml` で worktree の配置ディレクトリを設定でき、ブランチ名から自動でパスを決定してくれる。

## インストール

```bash
brew tap satococoa/tap
brew install satococoa/tap/wtp
```

`Brewfile` で管理されている。

## 設定

リポジトリルートに `.wtp.yml` を置く。

```yaml
worktree_dir: ../worktrees  # worktree を作成するディレクトリ（デフォルト）
```

## 基本的な使い方

```bash
# 新規ブランチで worktree を作成
wtp add -b feature/my-feature

# 既存ブランチの worktree を作成
wtp add feature/existing

# worktree 一覧を表示
wtp list

# worktree を削除（ブランチは残す）
wtp remove feature/my-feature

# worktree を削除してブランチも一緒に削除
wtp remove --with-branch feature/my-feature

# worktree に cd する
wtp cd feature/my-feature
```

## wtp add の出力フォーマット

```
✅ Worktree created successfully!

📁 Location: /path/to/worktrees/feature/my-feature
🌿 Branch: feature/my-feature

💡 To switch to the new worktree, run:
   wtp cd feature/my-feature
```

`Location:` 行からパスを取得できる（`WorktreeCreate` フックで利用）。

## wtp remove の引数

`wtp list`のPATH列に表示される名前（ブランチ名と同じ形式）を指定する。

```bash
wtp list
# PATH                  BRANCH                STATUS
# feature/my-feature    feature/my-feature    managed

wtp remove feature/my-feature  # PATH 列の値を指定
```

## このリポジトリでの使われ方

`claude --worktree <branch>` を実行すると `WorktreeCreate` フック（`~/.claude/hooks/worktree-create.sh`）が呼ばれ、内部で `wtp add -b <branch>` を実行する。セッション終了時の "remove" 選択では `WorktreeRemove` フックが `wtp remove <branch>` を実行する。

## 参考リンク

- [GitHub - satococoa/wtp](https://github.com/satococoa/wtp)
- [解説記事（Zenn）](https://zenn.dev/satococoa/articles/f93f34f0e13696)
