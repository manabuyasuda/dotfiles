---
name: worktree-add
description: >
  git worktreeを作成する。mainを最新化し、新しいworktreeを作成して.envrcをコピーし、
  エディターとSourceTreeで開く。「worktree作って」「新しいworktree」
  「ブランチ切って作業したい」で発火する。
context: fork
allowed-tools:
  - Bash
  - Read
  - Glob
  - Grep
  - AskUserQuestion
---

# worktree作成

以下の12ステップを番号順に実行する。各ステップには `[自動]` / `[ユーザー質問]` / `[実行]` のタグを示す。

---

## ステップ1: REPO_PATH を特定する [自動]

```bash
git rev-parse --show-toplevel 2>/dev/null
```

- リポジトリ内: そのパスを `REPO_PATH` とする
- リポジトリ外: 直下のディレクトリから `.git` がディレクトリ（ファイルではない）のものを探す

```bash
for d in */; do [ -d "$d.git" ] && echo "$d"; done
```

1つなら自動選択。複数ならAskUserQuestionで選んでもらう

## ステップ2: DEFAULT_BRANCH を取得する [自動]

```bash
git -C <REPO_PATH> symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@'
```

## ステップ3: BRANCH_NAME を確認する [ユーザー質問]

ブランチ名はユーザーが自由に決める。「Other」から入力してもらう想定で、選択肢は命名例として提示する:

```json
{
  "question": "作成するブランチ名を「Other」から入力してください",
  "options": [
    { "label": "feature/...", "description": "機能追加の命名例" },
    { "label": "fix/...", "description": "バグ修正の命名例" }
  ]
}
```

回答後に検証する（検証はここだけで行い、後のステップでは行わない）:

- `DEFAULT_BRANCH` と同名 → 禁止。理由を伝えて別名を求める
- 同名のローカルブランチが既存: `git -C <REPO_PATH> branch --list <BRANCH_NAME>` で確認。存在すれば別名を求める

## ステップ4: WORKTREE_DIR を確認する [ユーザー質問]

ディレクトリ名はユーザーのプロジェクト規約や好みによって異なるため、自動で決めず必ず確認する。`BRANCH_NAME` の `/` を `-` に変換した `SAFE_BRANCH` を使って選択肢を構成する:

```json
{
  "question": "worktreeのディレクトリ名を選択してください",
  "options": [
    { "label": "worktree-<SAFE_BRANCH>", "description": "worktree-接頭辞付き" },
    { "label": "<SAFE_BRANCH>", "description": "ブランチ名のみ" }
  ]
}
```

`<SAFE_BRANCH>` は実際の値に置き換えて表示する（例: ブランチ名が `feature/login` なら `worktree-feature-login` と `feature-login`）。

## ステップ5: EDITOR を確認する [ユーザー質問]

エディターはユーザーの好みによるため、自動で決めず必ず確認する。選択肢は以下の順序で提示する:

```json
{
  "question": "worktreeを開くエディターを選択してください",
  "options": [
    { "label": "VS Code", "description": "VS Codeの新しいウィンドウで開く" },
    { "label": "ターミナルのみ", "description": "エディターは開かない" }
  ]
}
```

## ステップ6: COPY_FILES を検出する [自動]

```bash
bash ~/.claude/skills/worktree-add/scripts/copy-gitignored-files.sh --list <REPO_PATH>
```

出力されたパスのリストを `COPY_FILES` として保持する（空でも可）。

---

ステップ3〜5の回答がすべて揃ったことを確認してから、以下の実行ステップに進む。

---

## ステップ7: デフォルトブランチを最新化する [実行]

```bash
git -C <REPO_PATH> checkout <DEFAULT_BRANCH> && git -C <REPO_PATH> pull origin <DEFAULT_BRANCH>
```

## ステップ8: worktreeを作成する [実行]

```bash
git -C <REPO_PATH> worktree add "../<WORKTREE_DIR>" -b <BRANCH_NAME>
```

`WORKTREE_PATH` は `$(dirname <REPO_PATH>)/<WORKTREE_DIR>` とする。

## ステップ9: ファイルパスをコピーする [実行]

```bash
bash ~/.claude/skills/worktree-add/scripts/copy-gitignored-files.sh <REPO_PATH> <WORKTREE_PATH>
```

## ステップ10: エディターで開く [実行]

EDITOR の回答に応じて実行する:
- **VS Code**: `code -n <WORKTREE_PATH>`
- **ターミナルのみ**: `cd <WORKTREE_PATH>` を案内する

## ステップ11: SourceTreeで開く [実行]

```bash
open -a SourceTree <WORKTREE_PATH>
```

## ステップ12: 未完了ステップの確認と再実行 [確認]

ステップ1〜11が実際に実行されたか確認し、実行されていないものがあれば実行してから次に進む:

- [ ] ステップ1: REPO_PATH を特定した
- [ ] ステップ2: DEFAULT_BRANCH を取得した
- [ ] ステップ3: BRANCH_NAME をユーザーに確認した
- [ ] ステップ4: WORKTREE_DIR をユーザーに確認した
- [ ] ステップ5: EDITOR をユーザーに確認した
- [ ] ステップ6: `copy-gitignored-files.sh --list` で COPY_FILES を検出した
- [ ] ステップ7: `git pull` でデフォルトブランチを最新化した
- [ ] ステップ8: `git worktree add` でworktreeを作成した
- [ ] ステップ9: `copy-gitignored-files.sh` でファイルをコピーした
- [ ] ステップ10: エディターで開いた（またはターミナルのみを選択した）
- [ ] ステップ11: `open -a SourceTree` を実行した

## ステップ13: 完了案内 [実行]

以下を表示する:
- worktreeのパス
- ブランチ名
- コピーしたファイル一覧（`COPY_FILES`。空なら「なし」）

続けて、新しいターミナルで1回貼り付けるだけで初期化が完了する初期化コマンドを作り、クリップボードにコピーする:

1. `COPY_FILES` に `.envrc` が含まれる → 先頭に `direnv allow;`（環境変数を後続コマンドより先に反映させるため）
2. ロックファイルが存在する場合 → インストールコマンドをバックグラウンドで実行（`&`）:
   - `package-lock.json` → `npm ci &`
   - `yarn.lock` → `yarn install --immutable &`
   - `pnpm-lock.yaml` → `pnpm install --frozen-lockfile &`
   - `bun.lockb` → `bun install --frozen-lockfile &`
3. 末尾に必ず追加 → `claude`

```bash
echo '<コマンド文字列>' | pbcopy
```

「クリップボードにコピーしました。新しいターミナルで貼り付けて実行してください」と案内する。
