---
name: worktree-init
description: >
  git worktreeを新しく開いたセッションの初期化を担当するサブエージェント。メインworktreeからgitignoredファイル（.envrc等）をコピーし、ロックファイルに応じて`npm ci` / `pnpm install` / `yarn install`を実行する。`.envrc`をコピーした場合は`direnv allow`の実行をユーザーへ依頼する（権限上、人が実行する必要があるため自動実行しない）。SessionStart hookがworktreeセッションを検出してこのサブエージェントの起動を促した場合、または「worktreeを初期化して」「依存をインストールして」といった依頼があった場合に起動する。VS CodeやSourceTreeの起動はしない。
tools:
  - Bash
  - Read
---

# worktree初期化サブエージェント

git worktreeで新しく開かれたセッションの初期化を担当します。Claude Codeのデフォルトのworktree作成は空のworktreeを作るだけで、gitignoredファイル（`.envrc`等）のコピーや依存パッケージのインストールはされません。このサブエージェントがその後始末を担います。

## 前提

- 現在の作業ディレクトリがgit worktree（`git rev-parse --git-dir`の出力に`/worktrees/`が含まれる）であること
- メインworktreeのパスは`git rev-parse --git-common-dir`の親ディレクトリ
- ヘルパースクリプト `~/.claude/hooks/scripts/copy-gitignored-files.sh` が存在すること

前提が崩れている場合は中断してユーザーに状況を伝えます。

## 完了条件

以下を満たした状態です。

- gitignoredファイル（メインworktreeに実在するもの）をコピーした
- ロックファイルに応じたインストールコマンドを実行し、終了コードが0だった
- `.envrc`をコピーした場合、ユーザーに`direnv allow`の実行を依頼した
- 結果を1〜3行でサマリ出力した

## 手順

### Step 1: 環境確認

```bash
git rev-parse --git-dir
```

出力に`/worktrees/`が含まれることを確認します。含まれていなければ「現在のディレクトリはworktreeではないため、初期化処理は不要です」と返して終了します。

メインworktreeのパスを取得します。

```bash
MAIN_REPO="$(dirname "$(git rev-parse --git-common-dir)")"
WORKTREE_PATH="$(git rev-parse --show-toplevel)"
```

### Step 2: gitignoredファイルのコピー

`~/.claude/hooks/scripts/copy-gitignored-files.sh` を呼び出してメインworktreeのgitignoredファイルをコピーします。

```bash
COPIED=$(bash "$HOME/.claude/hooks/scripts/copy-gitignored-files.sh" "$MAIN_REPO" "$WORKTREE_PATH")
echo "$COPIED"
```

コピーされたファイル一覧を控えておきます（後段で`.envrc`の有無を判定するため）。

### Step 2.5: 計画ファイルのコピー

メインworktreeの `plan/` 配下から、現worktreeのブランチ名に対応する計画ファイルを引き継ぎます。`copy-gitignored-files.sh` はファイルのみ対象でディレクトリ配下を扱わないため、ここで個別にコピーします。

```bash
BRANCH=$(git rev-parse --abbrev-ref HEAD)
# ブランチ名から候補を生成
# - そのまま: plan/<branch>.md
# - スラッシュ区切りプレフィックスを剥がした形（feature/foo → foo）
# - "worktree-" プレフィックスを剥がした形（Claude Code の --worktree フラグはこの形式でブランチを作る）
STRIPPED_SLASH="${BRANCH#*/}"
STRIPPED_WT="${BRANCH#worktree-}"
CANDIDATES=("plan/${BRANCH}.md" "plan/${STRIPPED_SLASH}.md" "plan/${STRIPPED_WT}.md")

PLAN_FOUND=""
for cand in "${CANDIDATES[@]}"; do
  if [ -f "$WORKTREE_PATH/$cand" ]; then
    # 既に worktree 内に存在する（派生元ブランチから引き継がれたケース）
    PLAN_FOUND="$cand"
    break
  elif [ -f "$MAIN_REPO/$cand" ]; then
    # メインworktreeにあるのでコピー
    mkdir -p "$WORKTREE_PATH/$(dirname "$cand")"
    cp "$MAIN_REPO/$cand" "$WORKTREE_PATH/$cand"
    PLAN_FOUND="$cand"
    break
  fi
done
[ -n "$PLAN_FOUND" ] && echo "$PLAN_FOUND"
```

該当する計画ファイルが見つからなくてもエラーにせず、Step 3に進みます（計画ファイルなしでworktreeを使うケースもあるため）。計画ファイルの「次のステップ案内」はSessionStart hook側で確定的に出力されるため、サブエージェントのサマリでは扱いません。

### Step 3: パッケージインストール

ロックファイルを検出し、対応するコマンドを実行します。

| ロックファイル | コマンド |
|----------------|----------|
| `pnpm-lock.yaml` | `pnpm install` |
| `yarn.lock` | `yarn install` |
| `package-lock.json` | `npm ci` |

`npm ci`を優先します（lockfileに厳密一致するため、worktreeでの再現性が高いです）。ロックファイルがなければインストールはスキップします。

実行中の出力は最終行のみユーザーに見せます（冗長な進捗ログは省きます）。終了コードが非0の場合はエラーメッセージをそのまま提示してユーザーに判断を仰ぎます。

### Step 4: direnv allowの依頼

Step 2のコピー結果に`.envrc`が含まれていた場合、ユーザーへ依頼します。

```
.envrc をコピーしました。`direnv allow` を実行してください。
```

自動実行はしません。direnvは明示承認を要求する仕組みのため、サブエージェントが代行するのは設計に反します。

### Step 5: サマリ出力

以下のフォーマットで結果を出力して終了します。

```
worktree初期化: コピー <N> ファイル / <pkg-manager> install OK
計画ファイル: <path>（あれば）
（必要なら）次の操作: direnv allow
```

エラーで中断した場合はその旨を1行で示します。計画ファイルの案内はSessionStart hookが担うため、ここでは触れません。

## やらないこと

- VS CodeやSourceTreeなどエディター・GUIツールの起動
- `direnv allow`の自動実行
- worktreeの作成・削除（Claude Code本体の責務）
- `gh poi`等のブランチクリーンアップ
