---
name: x-code-review-judgment
description: AIの判断が必要なコードレビューを実施します。Fowlerのコードスメル・プロジェクト規約・shallow module検出・テスタビリティのStandards軸と、変更の意図と実装の一致を確認するSpec軸の2軸で評価します。「レビューして」「コードレビューして」「judgment review」のように使います。静的解析ツールの実行はx-code-review-static、git履歴の分析はx-code-review-git-historyが担当します。
context: fork
allowed-tools:
  - Bash
  - Read
  - Glob
  - Grep
  - WebFetch
---

# 判断レビュー

機械が決定論的に検出できない問題を、差分と周辺コードを読んで評価します。評価はStandards軸（コードが規約と設計原則を満たすか）とSpec軸（コードが変更の意図を実現しているか）の2軸に分け、出力でも軸ごとに分けたまま示します。

## Step 1: 差分と意図を取得する

```bash
CURRENT_BRANCH=$(git branch --show-current)
BASE_BRANCH=$(git remote show origin | awk '/HEAD branch/ {print $NF}')
CHANGED_FILES=$(git diff --name-only origin/${BASE_BRANCH}...HEAD)
git log origin/${BASE_BRANCH}..HEAD --oneline
git diff origin/${BASE_BRANCH}...HEAD
```

引数にPR番号がある場合は`gh pr view <番号> --json title,body`と`gh pr diff <番号>`で取得します。

## Step 2: 判断基準を読み込む（Standards軸の準備）

- CLAUDE.mdと`.claude/rules/*.md`は自動で読み込まれている前提とし、その内容をそのまま判断基準に使います
- レビュー対象リポジトリにCODING_STANDARDS.md・CONTRIBUTING.md・ADR等の規約ファイルがある場合は、Readで読み込んで判断基準に加えます
- 読み込んだ規約ファイルの一覧を結果の冒頭に出力します

## Step 3: Standards軸で評価する

### コードスメル（Fowlerの12分類）

差分と周辺コードを読み、次の12のスメルに該当する箇所を探します。

<!-- textlint-disable @textlint-ja/ai-writing/ai-tech-writing-guideline, ja-technical-writing/ja-no-redundant-expression, prh -->

| スメル | 判断基準 |
|---|---|
| Mysterious Name | 名前から役割・意図が読み取れない関数・変数・クラスがある |
| Duplicated Code | 同じ構造のコードが複数箇所にある |
| Feature Envy | 関数が自分のモジュールより他のモジュールのデータに頻繁に触れている |
| Data Clumps | 同じデータの組が複数の関数シグネチャに繰り返し現れる |
| Primitive Obsession | ドメインの概念をstring・number等のプリミティブ型のまま引き回している |
| Repeated Switches | 同じ条件分岐が複数箇所に散らばっている |
| Shotgun Surgery | 1つの変更のために多数のファイルへ小さな修正が散らばっている |
| Divergent Change | 1つのモジュールが複数の異なる理由で変更されている |
| Speculative Generality | 現在使われていない汎用化・抽象化・引数がある |
| Message Chains | `a.b().c().d()`のように深いナビゲーションでオブジェクトを辿っている |
| Middle Man | 委譲しかしていないクラス・関数が間に挟まっている |
| Refused Bequest | 継承・インターフェイスの一部だけを使い、残りを無視または例外化している |

<!-- textlint-enable @textlint-ja/ai-writing/ai-tech-writing-guideline, ja-technical-writing/ja-no-redundant-expression, prh -->

### shallow module検出（deletion test）

対象はコードベース全体ではなく、今回の変更ファイルに限定します。

変更で追加・変更されたモジュール（関数・クラス・ファイル）ごとに、「このモジュールを削除して呼び出し側にインライン展開したら、コードは悪化するか」を問います。インライン展開しても悪化しないモジュールは、インターフェイスの複雑さに対して実装が薄いshallow moduleです。委譲しかしないラッパー・引数をそのまま横流しする関数・1箇所からしか呼ばれない小さな抽象を重点的に確認します。

### テスタビリティ3原則

変更で追加・変更された関数・コンポーネントが次の3原則を満たすかを確認します。

1. 依存を受け取る（グローバル・シングルトン・モジュールスコープの状態を直接参照するのではなく、引数・propsで受け取る）
2. 結果を返す（副作用で状態を書き換えるのではなく、戻り値で結果を表現する）
3. 表面を小さくする（テストで固定する必要のある入力・出力・依存の数を最小にする）

## Step 4: Spec軸で評価する

コードが「何を実現するはずだったか」を特定し、実装がそれと一致するかを確認します。

1. コミットメッセージとPR本文からissue参照（`#123`・`Closes #123`等）を抽出し、`gh issue view <番号>`で要求内容を取得します
2. レビュー対象リポジトリの`docs/`・`specs/`・`.scratch/`に、変更に関連する仕様・設計メモがあるかをGlobとGrepで探し、あれば読み込みます
3. 特定した意図と差分を突き合わせ、次を確認します
   - 要求された動作がすべて実装されているか（実装漏れ）
   - 要求されていない変更が混ざっていないか（スコープ外の変更）
   - 仕様と実装で解釈が分かれている箇所はないか

意図を特定できる情報源が1つも見つからない場合は、Spec軸の結果に「意図を特定できる情報源（issue・docs・specs）が見つからないため、Spec軸は評価できません」と書きます。

## Step 5: 2軸に分離して出力する

Standards軸とSpec軸を別々の節として出力します。指摘の記載と重要度の順位付けは、軸をまたぐのではなく、それぞれの軸の中で完結させます。

```
## 判断レビュー結果

### 読み込んだ判断基準
- <規約ファイルのパス一覧>

### Standards軸（規約・設計原則）

#### <ファイルパス>

**L<行番号>** [<must / should / nit>] <指摘内容>
> <該当コードの引用>
<理由と改善案。スメル名・原則名を明記します>

### Spec軸（意図と実装の一致）

- 参照した意図: <issue番号・仕様ファイルのパス>
- <実装漏れ / スコープ外の変更 / 解釈の分かれる箇所の指摘>
```

重要度は次の3段階です。

- `must` — バグ・セキュリティリスクなど、マージ前の修正が必要です
- `should` — 設計・可読性の改善など、強く推奨します
- `nit` — 些細な改善提案で、好みの範囲です

指摘が1件もない軸は「指摘なし」と1行で書きます。変更者への敬意を保ち、指摘には理由と改善案を添えた建設的なフィードバックを書きます。
