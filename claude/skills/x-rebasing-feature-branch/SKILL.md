---
name: x-rebasing-feature-branch
description: フィーチャーブランチをベースブランチ（main/master/developなど）にリベースし、リモートに反映するまでを1タスクとして実行するワークフローを提供します。「リベースして」「mainを取り込んで」「mainに追従して」「rebase」といった依頼、またはフィーチャーブランチがベースブランチから乖離している場合に使用します。
allowed-tools:
  - Bash
  - Read
  - Glob
  - Grep
  - AskUserQuestion
  - TaskCreate
  - TaskUpdate
  - TaskList
---

# フィーチャーブランチのリベース

## 完了条件

`git status -sb`でローカルとリモートが同期（ahead/behindなし）するまでは完了したとみなしません。`Successfully rebased`の表示やワーキングツリーのクリーン化は途中経過にすぎません。

## 実行フローの概要

ブランチ確定→状態確認→ベースブランチ最新化→ローカルrebase→[コンフリクト解消ループ→]リモートpush→完了確認

## タスク登録（実行開始時に必ず実施）

フローを開始する前に、全ステップを`TaskCreate`で登録します。各ステップを開始するとき`TaskUpdate`で`in_progress`へ、完了したとき`completed`へ更新します。

| # | subject | blockedBy |
|---|---------|-----------|
| 1 | Step 1: ブランチを確定する | — |
| 2 | Step 2: ベースブランチを最新化する | 1 |
| 3 | Step 3: フィーチャーブランチに戻ってリベースする | 2 |
| 4 | Step 4: リモートにプッシュする | 3 |
| 5 | Step 5: 完了確認 | 4 |

## 実行手順

### Step 1: ブランチを確定する

```bash
git branch --show-current
```

#### フィーチャーブランチの確認

フィーチャーブランチにいることを確認し、ブランチ名を`FEATURE_BRANCH`として記憶します。

#### ベースブランチの確定

ユーザーの最初の指示にブランチ名が含まれている場合（例:「developを取り込んで」「stagingにrebaseして」）は、そのブランチ名を提示してAskUserQuestionで確認します（yesまたは正しいブランチ名を入力してもらいます）。

```json
{
  "question": "ベースブランチは「<検出したブランチ名>」でよいですか？別のブランチの場合は入力してください。",
  "options": [
    { "label": "はい", "description": "<検出したブランチ名> にリベースします" }
  ]
}
```

含まれていない場合は、利用可能なローカルブランチを確認してからAskUserQuestionで確認します。

```bash
git branch | grep -v '^\*'
```

```json
{
  "question": "リベース先のベースブランチはどれですか？",
  "options": [
    { "label": "main", "description": "mainブランチにリベースします" },
    { "label": "develop", "description": "developブランチにリベースします" },
    { "label": "staging", "description": "stagingブランチにリベースします" }
  ]
}
```

ブランチ一覧に応じてoptionsを調整し（存在するブランチのみ提示）、ユーザーが選択した値を`BASE_BRANCH`として記憶します。

`FEATURE_BRANCH`と`BASE_BRANCH`の両方が確定したら次に進みます。

#### 未コミットの変更がある場合

```bash
git status --short
```

変更がある場合はAskUserQuestionで対応を選択してもらいます。

```json
{
  "question": "未コミットの変更があります。どうしますか？",
  "options": [
    { "label": "コミットする", "description": "変更をコミットしてからリベースします" },
    { "label": "スタッシュする", "description": "git stashで退避し、リベース後に復元します" }
  ]
}
```

ワーキングツリーがクリーンになってから次に進みます。

### Step 2: ベースブランチを最新化する

Step 1で確定した`BASE_BRANCH`を使います。

```bash
git checkout <BASE_BRANCH> && git pull origin <BASE_BRANCH>
```

### Step 3: フィーチャーブランチに戻ってリベースする

Step 1で記憶した`FEATURE_BRANCH`と`BASE_BRANCH`を使います。

```bash
git checkout <FEATURE_BRANCH> && git rebase <BASE_BRANCH>
```

コンフリクトが発生した場合は「コンフリクト発生時」セクションに進みます。発生しなかった場合はStep 4に進みます。

### Step 4: リモートにプッシュする

`--force-with-lease`を使うことで、他の人がプッシュした変更を誤って上書きするリスクを軽減します。

```bash
git push --force-with-lease origin <FEATURE_BRANCH>
```

### Step 5: 完了確認

```bash
git fetch origin <FEATURE_BRANCH> && git status -sb
```

期待される出力は`## <FEATURE_BRANCH>...origin/<FEATURE_BRANCH>`のみ（ahead/behindがゼロの状態）です。aheadが残っている場合はpushが失敗または不完全なので原因を調査して再pushします。behindが残っている場合は他の誰かが先にpushしているので、ユーザーに状況を報告して指示を仰ぎます。

完了確認に成功したら、ユーザーに以下を簡潔に報告して終了します。

- ベースブランチ名と取り込んだコミット数
- コンフリクトの発生したファイルがあれば、その解消方針

## コンフリクト発生時

リベース中にコンフリクトが発生した場合は、以下の手順A〜Dを繰り返します。すべて解消できて`Successfully rebased and updated <branch>`が表示されたら、メインフローのStep 4に戻ります。

### A. コンフリクトの内容を把握する

コンフリクトが発生したファイルを一覧で取得します。

```bash
git diff --name-only --diff-filter=U
```

各ファイルをReadツールで開いて、`<<<<<<<`〜`>>>>>>>`のマーカーを全箇所読んでください。この読み取りはスキップ禁止です。`merge.conflictstyle diff3`が設定されている場合は3区画になります。

| マーカー範囲 | 内容 |
|---|---|
| `<<<<<<< HEAD`〜`|||||||` | ベースブランチ側の変更内容 |
| `|||||||`〜`=======` | 共通祖先（両者が変更する前の元の内容） |
| `=======`〜`>>>>>>>` | フィーチャーブランチ側の変更内容 |

どちらかにしか存在しない行・型定義・import・設定項目がないかも確認します。

### B. mergirafで構造的コンフリクトを自動解消する

まずmergirafが利用可能か確認します。

```bash
command -v mergiraf
```

インストールされていなければこの手順をスキップして手順Cに進みます。

インストールされていれば、コンフリクトが発生しているファイルを確認し、1ファイルずつ`mergiraf solve`を実行します。

```bash
git diff --name-only --diff-filter=U
```

```bash
mergiraf solve <ファイルパス>
```

終了コードで次のアクションを判断します（xargsパイプラインでは終了コードがxargsのものになるため、1ファイルずつ処理します）。

| 終了コード | 意味 | 次のアクション |
|---|---|---|
| 0 | 全コンフリクトを解消 | mergirafの変更内容を報告（後述）→`git add` |
| 2 | 一部のコンフリクトのみ解消 | mergirafの変更内容を報告（後述）→残りを手順Cで手動解消後に`git add` |
| 1 | エラー（diff3が設定されていない・対応していないフォーマットなど） | そのファイルは手順Cへスキップ（mergirafによる変更はなし） |

#### mergirafの変更内容を報告する

終了コードが0または2のファイルは、`git add`または手順Cの手動解消へ進む前に、`mergiraf review <マージID>`を実行してユーザーへ変更内容を報告します。

```bash
mergiraf review <マージID>
```

報告には次を含めます。

- どの箇所をどう解消したかの要約
- 終了コードが2の場合は、解消できずに残ったコンフリクト箇所

すべてのファイルを処理したあと、残マーカーがないことを確認できれば手順Dへ進みます。

```bash
git diff --name-only --diff-filter=U
```

### C. 手動で解消方針をユーザーに確認する

mergirafで解消できなかったファイルを手動で解消します。各コンフリクト箇所の内容と解消後のコード例を提示してAskUserQuestionで承認を得ます。

> [!WARNING]
> - `--ours/--theirs`は、手順Aの確認で相手側に固有の変更が一切ないと確認できた場合のみ使用できます。確認を省くと有効な変更を無言で破棄します。
> - `--skip`は、手順Aの確認でフィーチャーブランチ側（`=======`〜`>>>>>>>`）にHEADに含まれない変更が一切ないと判断できた場合のみ使用できます。そうでない場合は`--ours`で解消して`--continue`するのが正しい手順です。

```json
{
  "question": "<ファイル名> のコンフリクトをどのように解消しますか？\n\n[ベースブランチ側]\n<HEAD側の変更内容>\n\n[フィーチャーブランチ側]\n<フィーチャーブランチ側の変更内容>",
  "options": [
    { "label": "両方取り込む", "description": "両方の変更をマージします（解消後のコードを提示して再確認します）" },
    { "label": "ベースブランチ側を優先", "description": "HEADの変更を採用し、フィーチャーブランチ側を破棄します。手順Aでフィーチャーブランチ側に固有の変更がないと確認済みの場合のみ選択できます" },
    { "label": "フィーチャーブランチ側を優先", "description": "フィーチャーブランチの変更を採用し、ベースブランチ側を破棄します。手順AでHEAD側に固有の変更がないと確認済みの場合のみ選択できます" },
    { "label": "このコミットをスキップ（--skip）", "description": "このコミット全体を履歴から削除します。手順Aでフィーチャーブランチ側にHEADに含まれない変更が一切ないと確認済みの場合のみ選択できます" }
  ]
}
```

### D. コードを修正してリベースを継続する

承認を得たら、コードを修正してコンフリクトマーカーを除去します。リンターが自動で変更する可能性がある場合は、その影響も考慮します。

```bash
git add <解消したファイル> && git rebase --continue
```

「このコミットをスキップ」を選択した場合は`git add`を実行せず、次のコマンドだけを実行します。

```bash
git rebase --skip
```

`git rebase --continue`（または`--skip`）の結果に応じて分岐します。

- `Successfully rebased and updated <branch>`が表示された場合は、メインフローのStep 4に戻ります。
- 後続のコミットで再度コンフリクトが発生した場合は、手順A〜Cを繰り返します。同じパターンでも再度の承認を得てからコードを修正します。

## 注意事項

- リベースを使うべきではない場合（共有ブランチ、公開済みコミットなど）は処理を中断して、ユーザーに報告します
- `--force`ではなく`--force-with-lease`を使用します
- ベースブランチに直接force pushしません
