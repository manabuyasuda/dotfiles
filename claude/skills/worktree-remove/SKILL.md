---
name: worktree-remove
description: >
  git worktreeを削除する。worktreeの状況を一覧表示し、選択したworktreeを安全に削除する。
  PRがOPENならworktreeのみ削除しブランチは残す。MERGED/CLOSEDならブランチも削除する。
  「worktree削除」「worktree片付けて」「PRマージしたので削除」「クリーンアップ」で発火する。
context: fork
allowed-tools:
  - Bash
  - Read
  - Glob
  - Grep
  - AskUserQuestion
---

# worktree削除

git worktreeの削除に伴う定型作業を安全に自動化する。

このスキルは **状況把握 → 選択 → 実行** の3フェーズで進める。削除は取り消せないので、状況を十分に把握してからユーザーに選択してもらう。

すべてのgit操作は `git -C <REPO_PATH>` で実行する。worktree内に `cd` すると、削除時にシェルが影響を受けるため。

---

## フェーズ1: 状況把握

### 1. 対象リポジトリを特定する

現在のディレクトリがGitリポジトリ内かどうかを確認する:

```bash
git rev-parse --show-toplevel 2>/dev/null
```

- **リポジトリ内の場合**: そのパスを `REPO_PATH` とする
- **リポジトリ外の場合**: 直下のディレクトリからメインリポジトリを探す。メインリポジトリは `.git` がディレクトリで、worktreeは `.git` がファイルなので区別できる:
  ```bash
  for d in */; do [ -d "$d.git" ] && echo "$d"; done
  ```
  1つなら自動選択。複数あればAskUserQuestionで選択してもらう。

### 2. worktree一覧とPR状態を取得する

worktree一覧を取得する:

```bash
git -C <REPO_PATH> worktree list
```

メインworktree（最初のエントリ）を除いたサブworktreeごとに、PRの状態を確認する:

```bash
gh pr list --head <branch> --state all --json number,state,title --repo <owner/repo>
```

### 3. 状況をテーブルで表示する

収集した情報をMarkdownテーブルで表示する:

```
| # | パス | ブランチ | PR | 状態 |
|---|------|---------|-----|------|
| 1 | ../worktree-feature-login | feature/login | #123 | MERGED |
| 2 | ../worktree-fix-bug | fix/bug | #456 | OPEN |
| 3 | ../worktree-refactor | refactor/cleanup | - | PR未作成 |
```

worktreeが1つもない場合は「削除可能なworktreeがありません」と伝えて終了する。

---

## フェーズ2: 削除対象の選択

### 4. 削除するworktreeを選択してもらう

AskUserQuestionの `multiSelect: true` を使い、チェックボックス形式で選択してもらう。テキストで質問してはならない。すべてのworktreeを選択肢に含める（OPEN状態のものも除外しない）。

各worktreeを1つのoptionにする。labelにブランチ名、descriptionにPR番号と状態を入れて、ユーザーが判断できるようにする:

```json
{
  "question": "削除するworktreeを選択してください（複数選択可）",
  "multiSelect": true,
  "options": [
    { "label": "feature/login", "description": "#123 MERGED" },
    { "label": "fix/bug", "description": "#456 OPEN" },
    { "label": "refactor/cleanup", "description": "PR未作成" }
  ]
}
```

AskUserQuestionのoptionsは最大4つまで。worktreeが5つ以上ある場合は複数回に分けて質問する。

### 5. OPEN状態のPRがある場合は確認する

選択されたworktreeの中にOPEN状態のPRがある場合、AskUserQuestionで確認する:

```json
{
  "question": "<branch>のPR #<number>はまだOPEN状態です。worktreeを削除しますか？（ブランチは削除しません）",
  "options": [
    { "label": "削除する", "description": "worktreeのみ削除し、ブランチとPRはそのまま残す" },
    { "label": "スキップする", "description": "このworktreeは削除しない" }
  ]
}
```

OPEN状態のPRが複数ある場合は、それぞれ個別に確認する。

### 6. 各worktreeの安全確認

選択されたworktreeごとに未コミットの変更と未プッシュのコミットを確認する:

```bash
git -C <worktree-path> status --short
git -C <worktree-path> log --oneline @{upstream}..HEAD 2>/dev/null
```

問題がある場合はユーザーに警告し、`--force` での削除を承認するか確認する。

---

## フェーズ3: 実行

### 7. worktreeを削除する

選択されたworktreeを削除する:

```bash
git -C <REPO_PATH> worktree remove <path>
```

未コミットの変更があり、ユーザーが `--force` を承認した場合のみ:

```bash
git -C <REPO_PATH> worktree remove --force <path>
```

### 8. SourceTreeのブックマークを削除する

ブランチ削除の前にこのステップを行う。ブランチを先に削除するとSourceTreeでエラーが表示されるため。

SourceTreeのブックマーク削除はCLIから自動化できないので、手動手順を案内する:

1. SourceTreeを開く
2. ブックマーク一覧から該当のworktreeリポジトリを右クリック
3. 「ブックマークから削除」を選択

複数削除した場合はまとめて案内する。ユーザーが操作を完了したことを確認してから次に進む。

### 9. ブランチを削除する

PR状態に応じて処理を分ける:

| PR状態 | worktree | ローカルブランチ | リモートブランチ |
|--------|----------|----------------|----------------|
| MERGED | 削除済み | 削除する | 削除を提案する |
| CLOSED | 削除済み | 削除する | 削除を提案する |
| OPEN | 削除済み | **削除しない** | **削除しない** |
| PR未作成 | 削除済み | 削除する | - |

MERGED/CLOSED/PR未作成のブランチを削除する。squashマージやリベースマージでは `git branch -d` が「マージされていない」と判定するため `-D` を使う:

```bash
git -C <REPO_PATH> branch -D <branch>
```

リモートブランチが残っている場合は削除を提案する:

```bash
git -C <REPO_PATH> push origin --delete <branch>
```

### 10. 完了案内

削除結果をまとめて表示する:

```
## 削除結果

| ブランチ | worktree | ローカルブランチ | リモートブランチ |
|---------|----------|----------------|----------------|
| feature/login | 削除済み | 削除済み | 削除済み |
| fix/bug | 削除済み | 残存（PR OPEN） | 残存（PR OPEN） |
```
