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

git worktreeの作成に伴う定型作業を自動化する。

このスキルは **ユーザーへの質問 → 実行** の2フェーズで進める。worktree作成はロールバックが面倒なので、必要な情報をすべて集めてから一気に実行する。

## 確定させる変数

以下の変数を上から順に確定させる。後の変数は前の変数に依存するため、必ずこの順番で1つずつ確定させる。

| # | 変数 | 確定方法 |
|---|------|---------|
| 1 | `REPO_PATH` | 自動検出 |
| 2 | `DEFAULT_BRANCH` | 自動検出 |
| 3 | `BRANCH_NAME` | AskUserQuestionツールで質問 |
| 4 | `WORKTREE_DIR` | AskUserQuestionツールで質問 |
| 5 | `EDITOR` | AskUserQuestionツールで質問 |

このフェーズではAskUserQuestionツールを最低3回呼び出す（#3, #4, #5）。ユーザーの意図を正確に反映するために、自分で推測して省略してはならない。

---

## フェーズ1: ユーザーへの質問

### 1. `REPO_PATH` を特定する

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

### 2. `DEFAULT_BRANCH` を検出する

```bash
git -C <REPO_PATH> symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@'
```

### 3. `BRANCH_NAME` — AskUserQuestionツールを呼び出す

ユーザーは「Other」から自由入力する想定なので、選択肢はブランチ命名の参考として提示する:

```json
{
  "question": "作成するブランチ名を「Other」から入力してください",
  "options": [
    { "label": "feature/...", "description": "機能追加の場合の命名例" },
    { "label": "fix/...", "description": "バグ修正の場合の命名例" }
  ]
}
```

ユーザーの入力がブランチ名ではなく作業内容の説明だった場合（例:「ログイン画面を作る」）:
1. 既存ブランチの命名パターンを確認する: `git -C <REPO_PATH> branch -a`
2. パターンに合った候補を2〜3個提案し、AskUserQuestionで選んでもらう

**検証**（ここで行い、実行フェーズでは行わない）:
- `DEFAULT_BRANCH`と同じ名前 → 禁止。理由を伝えて別名を求める
- 同名のローカルブランチがすでに存在 → エラーを伝えて別名を求める

### 4. `WORKTREE_DIR` — AskUserQuestionツールを呼び出す

`BRANCH_NAME` の `/` を `-` に変換した文字列を `SAFE_BRANCH` とし、それだけを使って選択肢を作る:

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

### 5. `EDITOR` — AskUserQuestionツールを呼び出す

```json
{
  "question": "worktreeを開くエディターを選択してください",
  "options": [
    { "label": "Cursor", "description": "Cursorの新しいウィンドウで開く" },
    { "label": "VS Code", "description": "VS Codeの新しいウィンドウで開く" },
    { "label": "ターミナルのみ", "description": "エディターは開かない" }
  ]
}
```

---

## フェーズ2: 実行

以下の5つがすべてユーザーの回答で確定していることを確認する。1つでも欠けていたらフェーズ1に戻る。

- [ ] `REPO_PATH` — 確定済み
- [ ] `DEFAULT_BRANCH` — 確定済み
- [ ] `BRANCH_NAME` — AskUserQuestionで回答済み
- [ ] `WORKTREE_DIR` — AskUserQuestionで回答済み
- [ ] `EDITOR` — AskUserQuestionで回答済み

すべてのgit操作は `git -C <REPO_PATH>` で行う。

### Step 1: デフォルトブランチを最新化する

```bash
git -C <REPO_PATH> checkout <DEFAULT_BRANCH> && git -C <REPO_PATH> pull origin <DEFAULT_BRANCH>
```

### Step 2: worktreeを作成する

`REPO_PATH` の親ディレクトリに `WORKTREE_DIR` を作成する:

```bash
git -C <REPO_PATH> worktree add "../<WORKTREE_DIR>" -b <BRANCH_NAME>
```

### Step 3: .envrcをコピーする

メインworktreeに `.envrc` がある場合のみコピーする:

```bash
[ -f "<REPO_PATH>/.envrc" ] && cp "<REPO_PATH>/.envrc" "<WORKTREE_PATH>/.envrc"
```

### Step 4: エディターとSourceTreeで開く

`EDITOR` の選択に応じて:
- **Cursor**: `cursor -n <WORKTREE_PATH>`
- **VS Code**: `code -n <WORKTREE_PATH>`
- **ターミナルのみ**: `cd <WORKTREE_PATH>` を案内

SourceTreeでも開く:
```bash
open -a SourceTree <WORKTREE_PATH>
```

### Step 5: 完了案内

以下を表示する:
- worktreeのパス
- ブランチ名
- コピーしたファイル（あれば）

追加の案内（該当する場合）:
- `.envrc` をコピーした場合 → `direnv allow` の実行が必要
- 依存パッケージのインストールコマンド。ロックファイルから判定する:
  - `package-lock.json` → `npm ci`
  - `yarn.lock` → `yarn install --frozen-lockfile`
  - `pnpm-lock.yaml` → `pnpm install --frozen-lockfile`
  - `bun.lockb` → `bun install --frozen-lockfile`

必ず実行する（スキップ禁止）:
- Claude Codeの起動コマンドをクリップボードにコピーする:
  ```bash
  echo 'unset CLAUDECODE && claude' | pbcopy
  ```
- 「クリップボードにコピーした内容を新しいターミナルで貼り付けてClaude Codeを起動してください」と案内する
