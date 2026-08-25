---
disable-model-invocation: true
name: x-cleanup-merged-branches
description: マージ済みのローカル・リモートブランチを整理するスキル。「ブランチ掃除」「マージ済みブランチを削除」「ブランチ整理」「gh poiを実行」「不要なブランチを片付けて」「リモートのブランチも消したい」「mainだけ残して」のような依頼で必ず使う。gh-poi拡張がインストール済みであることを前提とする。mainなどベースブランチは絶対に削除しない。他のworktreeがチェックアウトしているブランチも削除しない。
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

ローカルとリモートの両方で、ベースブランチと「保持対象」（マージされていない作業中のもの、および他のworktreeがチェックアウトしているもの）以外のブランチが削除された状態です。最後まで実行し、削除前後のブランチ数と、削除しなかったブランチの理由をユーザーに報告します。

## 前提

`seachicken/gh-poi`拡張をインストール済みであることを前提とします。インストールされていない場合はユーザーに`gh extension install seachicken/gh-poi`の実行を依頼してから続行します。

## 実行フローの概要

前提確認とベースラインの記録→worktree構成の把握→ベースブランチの確定→ベースブランチの最新化と`fetch --prune`→ローカルの整理（gh poi）→gh poiが削除しなかったローカルブランチの削除→リモート削除候補の抽出→ユーザーへの確認→リモートの削除→完了報告

## worktreeに関する原則

リポジトリが複数のworktreeを持つ場合、gitは「どこかのworktreeがチェックアウトしているブランチ」の削除と更新を拒否します。この制約を後から例外処理で対処するのではなく、Step 0で先にworktreeとブランチの対応を把握し、以降のすべての判定でその対応表を参照します。

このスキルはworktreeを削除しません。マージ済みでもworktreeが残っているブランチは削除候補から除外し、Step 7で「どのworktreeが使っているか」を添えて報告します。worktreeを削除するかどうかはユーザーが判断します。

## タスク登録（実行開始時に必ず実施）

フローを開始する前に、全ステップを`TaskCreate`で登録します。各ステップを開始するとき`TaskUpdate`で`in_progress`へ、完了したとき`completed`へ更新します。

| # | subject | blockedBy |
|---|---------|-----------|
| 1 | Step 0: 前提を確認しベースラインとworktree対応表を記録する | — |
| 2 | Step 1: ベースブランチを確定する | 1 |
| 3 | Step 2: ベースブランチを最新化する | 2 |
| 4 | Step 3: ローカルブランチをgh poiで整理する | 3 |
| 5 | Step 4: gh poiが削除しなかったローカルブランチを削除する | 4 |
| 6 | Step 5: リモートブランチの削除候補を抽出する | 5 |
| 7 | Step 6: 削除候補をユーザー確認してから一括削除する | 6 |
| 8 | Step 7: 完了報告 | 7 |

## 実行手順

### Step 0: 前提を確認しベースラインとworktree対応表を記録する

まず`gh poi --help`を実行し、コマンドが応答するかを確認します。応答しなければ中断してユーザーにインストールを依頼します。

続けてベースラインのブランチ数と、worktreeがチェックアウトしているブランチの一覧を記録します。どちらも以降のステップで参照するため、変数として保持しておきます。

```bash
gh poi --help
BEFORE_LOCAL=$(git branch --list | wc -l | tr -d ' ')
BEFORE_REMOTE=$(git ls-remote --heads origin | wc -l | tr -d ' ')
WT_BRANCHES=$(git worktree list --porcelain | awk '/^branch /{sub("refs/heads/","",$2); print $2}'; echo '__no_such_branch__')
```

`WT_BRANCHES`の末尾に付けたセンチネル行は、該当するworktreeが1つもないときの保険です。これがないと後段の`grep -xF "$WT_BRANCHES"`のパターンが空になり、全行に一致してしまいます。

`git worktree list --porcelain`は`worktree <パス>`と`branch refs/heads/<ブランチ名>`の行を対にして出力します。報告で「どのworktreeが使っているか」を示すため、ブランチ名だけでなくパスとの対応もあわせて読み取っておきます。detached HEADのworktreeには`branch`行が出力されないため、対応表には現れません。

`git branch --list`はworktreeの数にかかわらずリポジトリ全体のブランチを数えるため、`BEFORE_LOCAL`と`AFTER_LOCAL`の比較はそのまま成立します。

### Step 1: ベースブランチを確定する

`git symbolic-ref refs/remotes/origin/HEAD`でリモートのデフォルトブランチを取得します。取得できない場合や`main`以外が返った場合は、ユーザーに確認します。

確認した結果は以降の手順で`<BASE>`として扱います（多くの場合は`main`）。

### Step 2: ベースブランチを最新化する

どのworktreeが`<BASE>`をチェックアウトしているかで、最新化の方法が変わります。次の3つの場合に分けて判定します。

```bash
CURRENT=$(git symbolic-ref --short -q HEAD)
BASE_WT=$(git worktree list --porcelain | awk -v b="refs/heads/<BASE>" '/^worktree /{p=$2} $0=="branch "b{print p}')
```

| 場合 | 判定 | 実行するコマンド |
|---|---|---|
| いま自分が`<BASE>`にいる | `CURRENT`が`<BASE>`と一致する | `git pull origin <BASE>`（`git checkout`は不要） |
| 他のworktreeが`<BASE>`を使っている | `BASE_WT`が空でなく、自分のworktreeのパスと異なる | `git -C "$BASE_WT" pull origin <BASE>` |
| どこもチェックアウトしていない | `BASE_WT`が空 | `git checkout <BASE>`と`git pull origin <BASE>`。切り替えを避ける場合は`git fetch origin <BASE>:<BASE>` |

どの場合でも、最後に必ず`fetch --prune`を実行します。

```bash
git fetch --prune origin
```

`fetch --prune`は必須です。リモート側ですでに削除されたブランチの`origin/<branch>`参照がローカルに残っていると、Step 5の`--is-ancestor`判定が古いコミットを参照し、削除の可否を誤って判定します。

他のworktreeが`<BASE>`を使っている場合は、そのworktree側で`git -C`を使って更新します。自分のworktreeで`git checkout <BASE>`を実行するとgitが`fatal: '<BASE>' is already checked out at ...`で拒否し、同じ理由で`git fetch origin <BASE>:<BASE>`も拒否されるためです。

切り替えが必要な場合にコミットしていない変更などで失敗したときは、処理を止めてユーザーに対処を依頼します。stashや強制的な切り替えはユーザーの判断に委ね、このスキルからは実行しません。

`<BASE>`へ切り替えなかった場合、いま自分がいるブランチ自身は`git branch -d`で削除できません。そのブランチがStep 4の削除候補に入っている場合は、そのまま残してStep 7で「現在チェックアウトしているため削除しなかった」と報告します。

### Step 3: ローカルブランチをgh poiで整理する

まず`gh poi --dry-run`で削除対象を表示します。出力を要約してユーザーに提示し、削除対象が想定どおりかを目視で確認してもらいます。承認を得たら`gh poi`を実行します。

`gh poi`は「PRがマージされた（squash/rebase mergeを含む）ブランチ」を削除対象にします。PRなしで通常のマージコミットとして取り込まれたブランチはここでは残るため、Step 4で削除します。

他のworktreeがチェックアウトしているブランチは`gh poi`でも削除できず、「Branches not deleted」に残ります。Step 0の`WT_BRANCHES`と照合し、worktreeが理由で残ったものはこの時点で区別しておきます。

### Step 4: gh poiが削除しなかったローカルブランチを削除する

`git for-each-ref --merged <BASE> refs/heads/`で`<BASE>`の祖先になっているブランチを取得し、`<BASE>`自身と、worktreeがチェックアウトしているブランチを除いた一覧を削除候補とします。

```bash
CANDIDATES=$(git for-each-ref --format='%(refname:short)' --merged <BASE> refs/heads/ | grep -vxF '<BASE>')
SKIPPED_BY_WT=$(printf '%s\n' "$CANDIDATES" | grep -xF "$WT_BRANCHES")
DELETABLE=$(printf '%s\n' "$CANDIDATES" | grep -vxF "$WT_BRANCHES")
printf '%s\n' "$DELETABLE" | grep -v '^$' | xargs -r -n1 git branch -d
```

`SKIPPED_BY_WT`は「マージ済みでもworktreeが残っているブランチ」です。Step 5とStep 6でも削除対象から外し、Step 7で該当するworktreeのパスとあわせて報告します。

`git branch --merged`ではなく`git for-each-ref`を使います。detached HEADのworktreeがあると、`git branch`は`(HEAD detached at <hash>)`という疑似エントリを1行出力し、それが削除候補に混入するためです。`for-each-ref`は`refs/heads/`配下の実在するブランチだけを出力します。

削除には常に`-d`を使い、安全モードを維持します。`-d`は祖先関係を満たさないブランチの削除を拒否するため、想定外の削除を防げます。

### Step 5: リモートブランチの削除候補を抽出する

`git ls-remote --heads origin`でリモートブランチ一覧を取得し、`<BASE>`以外の各ブランチについて2つの軸で判定します。

| 軸 | 判定方法 |
|---|---|
| PR状態 | `gh pr list --state all --limit 1000 --json number,state,headRefName`を1回だけ実行し、結果を`headRefName`でマップ化してから、各ブランチのPR`state`を引き当てる |
| 祖先関係 | `git merge-base --is-ancestor origin/<branch> origin/<BASE>` |

`gh pr list`の取得件数が1000ちょうどだった場合は、PR一覧を取得しきれていない可能性があるため、警告して中断します。古いMERGED PRがマップから漏れると、squash mergeされたブランチは祖先関係でも検出できず、削除対象から外れます。

削除条件は次の通りです。

- 対応PRの状態が`MERGED`のブランチ、もしくは`<BASE>`の祖先になっているブランチ（PRなしでも内容が取り込み済みの場合）を削除対象にします
- 対応PRの状態が`OPEN`または`DRAFT`のブランチ、もしくは祖先ではなくPRもないブランチは、そのまま残します
- `WT_BRANCHES`に含まれるブランチは、上の条件を満たしていてもそのまま残します

最後の条件は、ローカルにworktreeが残っているブランチのリモート側を消すと、そのworktreeが上流を失って`git push`と`git pull`のどちらも実行できなくなるためです。ローカルとリモートで削除する範囲は必ず一致させます。

### Step 6: 削除候補をユーザー確認してから一括削除する

削除候補を「ブランチ名（削除理由）」の形でユーザーに提示し、承認を得ます。このとき、worktreeを理由に除外したブランチも「除外したもの」として同じ一覧に含め、判断材料にしてもらいます。承認後、`git push origin --delete`の1回の呼び出しに全候補を指定して一括削除します。`--porcelain`を付けることで、ブランチごとの成功・失敗を機械的にパースできます。

```bash
git push --porcelain origin --delete <branch1> <branch2> <branch3>
```

`git push`はrefspecごとに個別評価されるため、部分失敗が起こり得ます（権限不足・ブランチ保護・すでに削除済みなど）。`--porcelain`の出力から成功したブランチと失敗したブランチを分けて、最終報告に含めます。

### Step 7: 完了報告

Step 0で記録した`BEFORE_LOCAL`・`BEFORE_REMOTE`と、削除後の値を比較します。

```bash
git worktree prune
AFTER_LOCAL=$(git branch --list | wc -l | tr -d ' ')
AFTER_REMOTE=$(git ls-remote --heads origin | wc -l | tr -d ' ')
```

`git worktree prune`は、ユーザーがディレクトリを手動で削除したまま管理情報だけ残っているworktreeの記録を削除します。ディレクトリが存在するworktreeはそのまま残します。

以下を簡潔に報告します。

- 削除前後のローカルブランチ数と差分を示します
- 削除前後のリモートブランチ数と差分を示します
- リモート一括削除で部分失敗が出ていれば、成功したブランチと失敗したブランチを分けて提示します
- worktreeを理由に削除しなかったブランチを、対応するworktreeのパスとあわせて一覧にします。あわせて「作業が終わっているなら`git worktree remove <パス>`で削除してから再実行できます」と添えます
- 残ったブランチ一覧を提示し、`<BASE>`以外で残っているものがあればその理由を添えます

## エッジケースと例外

### worktreeがチェックアウトしているブランチ

gitは、いずれかのworktreeがチェックアウトしているブランチの削除と更新を拒否します。`git branch -d`は`Cannot delete branch 'x' checked out at ...`、`git checkout`と`git fetch origin x:x`は`already checked out at ...`で失敗します。

このスキルはこれらを失敗として扱わず、Step 0の対応表であらかじめ除外します。worktree自体は削除しません。マージ済みなのにworktreeが残っている状態には、削除し忘れている場合と作業を再開する予定がある場合の両方があり、どちらなのかをスキルが判断できないためです。ユーザーが`git worktree remove`でworktreeを削除したあとに再実行すれば、通常のマージ済みブランチとして削除されます。

### gh poiが「Branches not deleted」として残したブランチ

「PRがない」「PRがOPEN」「worktreeがチェックアウトしている」「ロックされている」のいずれかが理由です。Step 4で`<BASE>`の祖先になっているブランチを取得するため、PRがないだけのブランチはそこで削除されます。OPEN PRがあるブランチは作業中のため、そのまま残します。worktreeが理由で残ったものはStep 7で報告します。

### リモートで削除権限がない場合

`git push --porcelain origin --delete`の出力に`!`や`[remote rejected]`が出た場合は、ブランチ保護設定（GitHub側）または権限不足が原因です。`--porcelain`出力をそのままユーザーに見せて、判断を委ねます。

### ベースブランチが`main`以外（`master`/`develop`等）の場合

Step 1で確認した`<BASE>`を最後まで一貫して使います。`origin/HEAD`のシンボリックリンクが古い場合は`git remote set-head origin --auto`で更新してから再取得します。
