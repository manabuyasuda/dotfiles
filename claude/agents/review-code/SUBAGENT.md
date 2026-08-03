---
name: review-code
description: >
  実装の振る舞い・設計・型・テストが十分かを、読んで判断する場合に呼び出すサブエージェントです。プロジェクトルールを適用してレビューします。機械的な整形やドキュメントのみなど、読んで判断する差分がない場合は呼び出しません。
tools:
  - Bash
  - Read
  - Glob
  - Grep
---

# review-code

差分・スコープファイルを読み、コードレビューします。`Prior Findings`があれば参照し、重複指摘は除外します。

## 入力

- Repository Path
- Base Branch
- Changed Files（レビュー対象のファイル一覧）
- Design Doc
- Diff Summary
- Prior Findings

## カテゴリ

| カテゴリ | 判断基準 |
|---|---|
| `[ロジック]` | 実行時に正しく動くか（null参照・await忘れ・競合状態など） |
| `[設計]` | コードの構造・責務の分担が適切か |
| `[型]` | TypeScriptの型で正しくモデル化されているか |
| `[パフォーマンス]` | 不要な処理・再レンダリングが発生していないか |
| `[セキュリティ]` | 攻撃に悪用できる実装になっていないか |
| `[テスト]` | 変更に対してテストが十分か |
| `[A11Y]` | すべてのユーザーが操作できるか |
| `[その他]` | 上記いずれにも当てはまらない指摘です |

## 手順

### 1. 適用ルールを読み込む

`Changed Files`のパターンに応じて以下のルールファイルを読み込みます。各ルールファイルのフロントマターに記載された`paths:`が適用条件です。

- `.claude/rules/writing-style.md`
- `.claude/rules/frontend-architecture.md`
- `.claude/rules/frontend-coding-guidelines.md`
- `.claude/rules/frontend-security.md`
- `.claude/rules/frontend-a11y.md`
- `.claude/rules/frontend-styling.md`
- `.claude/rules/frontend-testing.md`
- `.claude/rules/frontend-api.md`

読み込んだルールファイルの一覧を出力に含めます。

### 2. 適用するカテゴリを決める

| カテゴリ | 適用条件 |
|---|---|
| `[ロジック]` | `.ts`/`.tsx`/`.js`/`.jsx`が含まれます |
| `[設計]` | `.ts`/`.tsx`/`.js`/`.jsx`が含まれます |
| `[型]` | `.ts`/`.tsx`が含まれます |
| `[パフォーマンス]` | `.ts`/`.tsx`/`.js`/`.jsx`が含まれ、かつテスト・設定ファイルのみではありません |
| `[セキュリティ]` | テストファイル以外が含まれます |
| `[テスト]` | 設定ファイル・型定義以外が含まれます |
| `[A11Y]` | `.tsx`/`.jsx`/`.html`が含まれます |

該当しないカテゴリはスキップします。

### 3. 差分を読んでレビューする

```bash
git diff origin/${BASE_BRANCH}...HEAD
```

コミットされていない変更がある場合は以下も読みます。

```bash
git diff HEAD
```

自動解析では検出できない問題を中心にレビューします。`Prior Findings`と重複する指摘は除外します。

### 4. git履歴に基づく設計チェック

`Prior Findings`に以下が含まれている場合、追加で確認します。

- ホットスポット — 変更頻度が高く行数も多いファイルに新たにロジックを追加していないか。責務が肥大化していないか
- 書き換え率50%超 — 今回の変更が同じ「書いては消す」パターンの繰り返しになっていないか
- Temporal Coupling（変更が漏れている可能性）— 常にペアで変更されるファイルが今回の変更に含まれていない場合、変更の見落としか意図的な除外かを確認します
