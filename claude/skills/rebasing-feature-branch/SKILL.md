---
name: rebasing-feature-branch
description: フィーチャーブランチをmainブランチにリベースするワークフローを提供する。「リベースして」「mainを取り込んで」「mainに追従して」「rebase」といった依頼、またはフィーチャーブランチがmainから乖離している場合に使用する。
context: fork
allowed-tools:
  - Bash
---

# フィーチャーブランチのリベース

## 概要

**目的**: フィーチャーブランチにmainブランチの最新変更を、リベースで見通しよく、安全に取り込む。

**フロー**: main checkout → pull → feature checkout → rebase → push

---

## 実行手順

### Step 1: 現在の状態を確認

```bash
git branch --show-current && git status --short
```

**ブランチの確認:**

- `main` や `staging` などの保護ブランチにいる場合 → ユーザーにフィーチャーブランチへの切り替えを促して中断する
- フィーチャーブランチにいることを確認してから次へ進む

**未コミットの変更がある場合:**

- 変更内容をユーザーに提示し、以下のどちらかを選択してもらう:
  - コミットする → `/commit` で対応
  - スタッシュする → `git stash` で退避（リベース後に `git stash pop` で復元）
- ワーキングツリーがクリーンになってから次へ進む

### Step 2: 現在のブランチ名を保存

```bash
FEATURE_BRANCH=$(git branch --show-current)
echo "フィーチャーブランチ: $FEATURE_BRANCH"
```

### Step 3: mainブランチを最新化

```bash
git checkout main && git pull origin main
```

### Step 4: フィーチャーブランチに戻ってリベース

```bash
git checkout "$FEATURE_BRANCH" && git rebase main
```

### Step 5: リモートにプッシュ

リベース成功後、force pushする：

```bash
git push --force-with-lease origin "$FEATURE_BRANCH"
```

---

## コンフリクト発生時

リベース中にコンフリクトが発生した場合：

### 1. コンフリクトの内容を把握する

- コンフリクトが発生したファイルを一覧で提示する
- 各ファイルのコンフリクト箇所（`<<<<<<<` 〜 `>>>>>>>`）を読み、HEAD（main側）とフィーチャーブランチ側の変更内容を把握する

### 2. 解消方針をユーザーに提案する

**承認があるまでコードの修正は絶対に実行しない。** 
以下の情報をユーザーに提示する:

- **どちらを優先するか？** main側 / フィーチャーブランチ側 / 両方取り込む
- **取り込み後に調整が必要か？** 必要なら具体的に何が必要か？
- **解消後のコード例**

### 3. ユーザーの承認後にコードを修正する

- 承認を得たら、コードを修正してコンフリクトマーカーを除去する
- リンターが自動で変更する可能性がある場合は、その影響も考慮する

### 4. 解消後にリベースを継続する

```bash
git add <解消したファイル> && git rebase --continue
```

- 後続のコミットで同じファイルに再度コンフリクトが発生する場合がある
- その場合は手順1〜3を繰り返す
- **同じパターンであっても、再度の承認を得るまでコードの修正は絶対に実行しない。** 

### 5. すべてのコンフリクト解消後にプッシュする

```bash
git push --force-with-lease origin "$(git branch --show-current)"
```

---

## 注意事項

- リベースを使うべきではない場合は処理を中断して、ユーザーに報告する
- `--force-with-lease` を使用する（`--force` は使わない）
- mainブランチに直接force pushしない
- リベース前に未コミットの変更がないことを確認する
- コンフリクト解消は必ずユーザーの確認を得てから行う
