---
name: rebasing-feature-branch
description: フィーチャーブランチをベースブランチ（main/master/developなど）にリベースするワークフローを提供する。「リベースして」「mainを取り込んで」「mainに追従して」「rebase」といった依頼、またはフィーチャーブランチがベースブランチから乖離している場合に使用する。
allowed-tools:
  - Bash
  - Read
  - Glob
  - Grep
  - AskUserQuestion
---

# フィーチャーブランチのリベース

フィーチャーブランチにベースブランチの最新変更を、リベースで見通しよく安全に取り込む。

**フロー**: ブランチ確定 → 状態確認 → ベースブランチ最新化 → リベース →[コンフリクト解消 →]プッシュ

---

## 実行手順

### Step 1: ブランチを確定する

まず現在のブランチとベースブランチ（リベース先）を確定する。

```bash
git branch --show-current
```

**フィーチャーブランチの確認:**

- フィーチャーブランチにいることを確認し、ブランチ名を `FEATURE_BRANCH` として記憶する

**ベースブランチの確定:**

ユーザーの最初の指示にブランチ名が含まれている場合（例:「developを取り込んで」「stagingにrebaseして」）は、そのブランチ名を提示してAskUserQuestionで確認する（yesまたは正しいブランチ名を入力してもらう）。

```json
{
  "question": "ベースブランチは「<検出したブランチ名>」でよいですか？別のブランチの場合は入力してください。",
  "options": [
    { "label": "はい", "description": "<検出したブランチ名> にリベースする" }
  ]
}
```

含まれていない場合は、利用可能なローカルブランチを確認してからAskUserQuestionで確認する。

```bash
git branch | grep -v '^\*'
```

```json
{
  "question": "リベース先のベースブランチはどれですか？",
  "options": [
    { "label": "main", "description": "mainブランチにリベースする" },
    { "label": "develop", "description": "developブランチにリベースする" },
    { "label": "staging", "description": "stagingブランチにリベースする" }
  ]
}
```

ブランチ一覧に応じてoptionsを調整し（存在するブランチのみ提示）、ユーザーが選択した値を `BASE_BRANCH` として記憶する。

`FEATURE_BRANCH` と `BASE_BRANCH` の両方が確定したら次に進む。

**未コミットの変更がある場合:**

```bash
git status --short
```

変更がある場合はAskUserQuestionで対応を選択してもらう。

```json
{
  "question": "未コミットの変更があります。どうしますか？",
  "options": [
    { "label": "コミットする", "description": "変更をコミットしてからリベースする" },
    { "label": "スタッシュする", "description": "git stashで退避し、リベース後に復元する" }
  ]
}
```

ワーキングツリーがクリーンになってから次へ進む。

### Step 2: ベースブランチを最新化する

Step 1で確定した `BASE_BRANCH` を使う。

```bash
git checkout <BASE_BRANCH> && git pull origin <BASE_BRANCH>
```

### Step 3: フィーチャーブランチに戻ってリベースする

Step 1で記憶した `FEATURE_BRANCH` と `BASE_BRANCH` を使う。Bashの環境変数はコマンド間で保持されないため、ブランチ名を直接埋め込む。

```bash
git checkout <FEATURE_BRANCH> && git rebase <BASE_BRANCH>
```

コンフリクトが発生した場合は「コンフリクト発生時」セクションに進む。

### Step 4: リモートにプッシュする

`--force-with-lease` を使うことで、他の人がプッシュした変更を誤って上書きするリスクを軽減する。

```bash
git push --force-with-lease origin <FEATURE_BRANCH>
```

---

## コンフリクト発生時

リベース中にコンフリクトが発生した場合は、以下の手順を繰り返す。すべて解消できたらStep 4に進む。

### 1. コンフリクトの内容を把握する

- コンフリクトが発生したファイルを一覧で提示する
- 各ファイルのコンフリクト箇所（`<<<<<<<` 〜 `>>>>>>>`）を読み、HEAD（ベースブランチ側）とフィーチャーブランチ側の変更内容を把握する

### 2. 解消方針をユーザーに確認する

コンフリクト解消はユーザーの意図に大きく依存するため、各コンフリクト箇所の内容と解消後のコード例を提示してAskUserQuestionで承認を得る。

```json
{
  "question": "<ファイル名> のコンフリクトをどのように解消しますか？\n\n[ベースブランチ側]\n<HEAD側の変更内容>\n\n[フィーチャーブランチ側]\n<フィーチャーブランチ側の変更内容>",
  "options": [
    { "label": "ベースブランチ側を優先", "description": "HEADの変更を採用し、フィーチャーブランチ側を破棄する" },
    { "label": "フィーチャーブランチ側を優先", "description": "フィーチャーブランチの変更を採用し、ベースブランチ側を破棄する" },
    { "label": "両方取り込む", "description": "両方の変更をマージする（解消後のコードを提示して再確認する）" }
  ]
}
```

### 3. コードを修正してリベースを継続する

承認を得たら、コードを修正してコンフリクトマーカーを除去する。リンターが自動で変更する可能性がある場合は、その影響も考慮する。

```bash
git add <解消したファイル> && git rebase --continue
```

後続のコミットで同じファイルに再度コンフリクトが発生することもある。その場合は手順1〜3を繰り返す。同じパターンでも再度の承認を得てからコードを修正する。

---

## 注意事項

- リベースを使うべきではない場合（共有ブランチ、公開済みコミットなど）は処理を中断して、ユーザーに報告する
- `--force` ではなく `--force-with-lease` を使用する
- ベースブランチに直接force pushしない
