---
name: x-cleanup-merged-branches
description: マージ済みのローカル・リモートブランチを整理するスキル。「ブランチ掃除」「マージ済みブランチを削除」「ブランチ整理」「gh poiを実行」「不要なブランチを片付けて」「リモートのブランチも消したい」「mainだけ残して」のような依頼で必ず使う。gh-poi拡張がインストール済みであることを前提とする。mainなどベースブランチは絶対に削除しない。
allowed-tools:
  - Bash
  - Read
  - AskUserQuestion
  - TaskCreate
  - TaskUpdate
  - TaskList
---

# マージ済みブランチの整理

## 完了条件

ローカルとリモートの両方で、ベースブランチと「保持対象」（マージされていない作業中のもの）以外のブランチが削除された状態です。途中で止めず、最後に必ず削除前後のブランチ数をユーザーに報告します。

## 前提

`seachicken/gh-poi`拡張をインストール済みであることを前提とします。インストールされていない場合はユーザーに`gh extension install seachicken/gh-poi`の実行を依頼してから続行します。

## 実行フローの概要

前提確認とベースラインカウント→ベースブランチ確定→ベースブランチ最新化と`fetch --prune`→ローカル整理（gh poi）→ローカル取りこぼし回収→リモート削除候補抽出→ユーザー確認→リモート削除→完了報告

## タスク登録（実行開始時に必ず実施）

フローを開始する前に、全ステップを`TaskCreate`で登録します。各ステップを開始するとき`TaskUpdate`で`in_progress`へ、完了したとき`completed`へ更新します。

| # | subject | blockedBy |
|---|---------|-----------|
| 1 | Step 0: 前提確認とベースラインを取得する | — |
| 2 | Step 1: ベースブランチを確定する | 1 |
| 3 | Step 2: ベースブランチへ切替して最新化する | 2 |
| 4 | Step 3: ローカルブランチをgh poiで整理する | 3 |
| 5 | Step 4: gh poiが拾えなかったローカルブランチを処理する | 4 |
| 6 | Step 5: リモートブランチの削除候補を抽出する | 5 |
| 7 | Step 6: 削除候補をユーザー確認してから一括削除する | 6 |
| 8 | Step 7: 完了報告 | 7 |

## 実行手順

### Step 0: 前提確認とベースラインを取得する

まず`gh poi --help`を実行し、コマンドが応答するかを確認します。応答しなければ中断してユーザーにインストールを依頼します。

続けてベースラインのブランチ数を記録します。Step 7の差分報告に使うので、変数として保持しておきます。

```bash
gh poi --help
BEFORE_LOCAL=$(git branch --list | wc -l | tr -d ' ')
BEFORE_REMOTE=$(git ls-remote --heads origin | wc -l | tr -d ' ')
```

### Step 1: ベースブランチを確定する

`git symbolic-ref refs/remotes/origin/HEAD`でリモートのデフォルトブランチを取得します。取得できない、または`main`以外が返った場合はユーザーに確認します。

確認した結果は以降の手順で`<BASE>`として扱います（多くの場合は`main`）。

### Step 2: ベースブランチへ切替して最新化する

```bash
git checkout <BASE>
git pull origin <BASE>
git fetch --prune origin
```

`fetch --prune`は必須です。リモート側ですでに削除されたブランチの`origin/<branch>`参照がローカルに残っていると、Step 5の`--is-ancestor`判定が古いコミットを見てしまい、削除判定が壊れます。

切替に失敗する場合（コミットしていない変更がある等）は止めてユーザーに対処を依頼します。勝手にstashや強制切替はしません。

### Step 3: ローカルブランチをgh poiで整理する

まず`gh poi --dry-run`で削除対象を表示します。出力を要約してユーザーに提示し、削除対象が想定通りかを目視確認してもらいます。承認を得たら`gh poi`を実行します。

`gh poi`は「PRがマージされた（squash/rebase mergeを含む）ブランチ」を削除対象にします。PRなしで通常マージコミットで取り込まれたブランチはここでは残るので、Step 4で回収します。

### Step 4: gh poiが拾えなかったローカルブランチを処理する

`git branch --merged <BASE>`で`<BASE>`の祖先になっているブランチを取得し、`<BASE>`自身を除いた一覧を削除候補とします。

```bash
git branch --merged <BASE> | grep -v "^[* ] <BASE>$" | xargs -n1 git branch -d
```

`-D`は使わず、`-d`の安全モードを維持します。`-d`は祖先関係を満たさないブランチの削除を拒否するため、想定外の削除を防げます。

### Step 5: リモートブランチの削除候補を抽出する

`git ls-remote --heads origin`でリモートブランチ一覧を取得し、`<BASE>`以外の各ブランチについて2軸で判定します。

| 軸 | 判定方法 |
|---|---|
| PR状態 | `gh pr list --state all --limit 1000 --json number,state,headRefName`を1回だけ叩き、結果を`headRefName`でマップ化してから、各ブランチのPR`state`を引き当てる |
| 祖先関係 | `git merge-base --is-ancestor origin/<branch> origin/<BASE>` |

`gh pr list`の取得件数が1000ちょうどだった場合は、PR一覧を取りきれていない可能性があるので警告して中断します。古いMERGED PRがマップから漏れると、squash mergeされたブランチが祖先関係でも検出できず「削除されない」に倒れて取りこぼします。

削除条件は次の通りです。

- 対応PRの状態が`MERGED`のブランチ、もしくは`<BASE>`の祖先になっているブランチ（PRなしでも内容が取り込み済みの場合）を削除対象にします
- 対応PRの状態が`OPEN`または`DRAFT`のブランチ、もしくは祖先ではなくPRもないブランチは削除しません

### Step 6: 削除候補をユーザー確認してから一括削除する

削除候補を「ブランチ名（削除理由）」の形でユーザーに提示し、承認を得ます。承認後、`git push origin --delete`の1回の呼び出しに全候補を並べて一括削除します。`--porcelain`を付けることで、ブランチごとの成功・失敗を機械的にパースできます。

```bash
git push --porcelain origin --delete <branch1> <branch2> <branch3> ...
```

`git push`はrefspecごとに個別評価されるため、部分失敗が起こり得ます（権限不足・ブランチ保護・すでに削除済みなど）。`--porcelain`の出力から成功したブランチと失敗したブランチを分けて、最終報告に含めます。

### Step 7: 完了報告

Step 0で記録した`BEFORE_LOCAL`・`BEFORE_REMOTE`と、削除後の値を比較します。

```bash
AFTER_LOCAL=$(git branch --list | wc -l | tr -d ' ')
AFTER_REMOTE=$(git ls-remote --heads origin | wc -l | tr -d ' ')
```

以下を簡潔に報告します。

- 削除前後のローカルブランチ数と差分を示します
- 削除前後のリモートブランチ数と差分を示します
- リモート一括削除で部分失敗が出ていれば、成功したブランチと失敗したブランチを分けて提示します
- 残ったブランチ一覧を提示し、`<BASE>`以外で残っているものがあればその理由を添えます

## エッジケースと例外

### gh poiが「Branches not deleted」として残したブランチ

「PRがない」「PRがOPEN」「ロックされている」のいずれかが理由です。Step 4で`<BASE>`の祖先になっているブランチを拾うので、PRがないだけのブランチは自動的に削除されます。OPEN PRがあるブランチは作業中なので削除しません。

### リモートで削除権限がない場合

`git push --porcelain origin --delete`の出力に`!`や`[remote rejected]`が出た場合は、ブランチ保護設定（GitHub側）または権限不足が原因です。`--porcelain`出力をそのままユーザーに見せて、判断を委ねます。

### ベースブランチが`main`以外（`master`/`develop`等）の場合

Step 1で確認した`<BASE>`を最後まで一貫して使います。`origin/HEAD`のシンボリックリンクが古い場合は`git remote set-head origin --auto`で更新してから再取得します。
