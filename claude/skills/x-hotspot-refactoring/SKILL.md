---
name: x-hotspot-refactoring
description: >
  git logのhotspot分析・循環参照・デッドコード・不安定性メトリクスを組み合わせて
  リファクタリング優先候補を提案する。「hotspot」「リファクタリング提案して」
  「どこを直すべき」「技術的負債を調べて」のように使う。
allowed-tools:
  - Bash
  - Glob
  - AskUserQuestion
  - Agent
  - TaskCreate
  - TaskUpdate
  - TaskList
---

# hotspot-refactoring

git履歴・静的解析・依存関係分析を組み合わせ、リファクタリング投資対効果がもっとも高い箇所を提案するスキルです。分析の実体は`hotspot-analyzer`エージェントに委譲し、このスキルはスコープ・観点の確認と提案の提示を担います。

**フロー**: スコープ確認 → 観点確認 → hotspot-analyzer起動 → 提案提示

## タスク登録（実行開始時に必ず実施）

フローを開始する前に、全ステップを`TaskCreate`で登録します。各ステップを開始するとき`TaskUpdate`で`in_progress`へ、完了したとき`completed`へ更新します。

| # | subject | blockedBy |
|---|---------|-----------|
| 1 | Step 1: スコープを確認する | — |
| 2 | Step 2: リファクタリングの観点を確認する | 1 |
| 3 | Step 3: hotspot-analyzer エージェントを起動する | 2 |
| 4 | Step 4: 提案を提示する | 3 |

## Step 1: スコープを確認する

プロジェクトの構成を把握します。

```bash
# 言語・フレームワークの自動検出
ls package.json tsconfig.json pyproject.toml Cargo.toml go.mod 2>/dev/null
```

AskUserQuestionツールで対象範囲を質問します。

```json
{
  "question": "リファクタリング分析の対象範囲を選択してください",
  "options": [
    { "label": "プロジェクト全体", "description": "すべてのソースコードを分析する" },
    { "label": "特定のディレクトリ", "description": "Otherから対象パスを入力（例: src/features/）" }
  ]
}
```

回答と自動検出の結果から以下の変数を決定します。

- `TARGET_DIR`: 分析対象ディレクトリ（未指定の場合は `.`）
- `IS_TS`: TypeScript/JSプロジェクトか（madge・knip・type-coverageの使用可否）
- `SINCE`: git分析の期間（デフォルト: `12.month`）

## Step 2: リファクタリングの観点を確認する

AskUserQuestionツールの `multiSelect: true` で質問します。

```json
{
  "question": "どの観点で分析しますか？（複数選択可。気になることがあればOtherに自由記述も可）",
  "multiSelect": true,
  "options": [
    { "label": "ホットスポット", "description": "頻繁に変更される・複雑なファイルを特定する" },
    { "label": "構造・依存関係", "description": "循環参照・隠れた結合・アーキテクチャ違反" },
    { "label": "デッドコード削減", "description": "未使用ファイル・未使用エクスポート" },
    { "label": "お任せ", "description": "すべての観点で分析する" }
  ]
}
```

AskUserQuestionは最大4選択肢のため、IS_TSがtrueの場合は追加でもう1回質問します。

```json
{
  "question": "TypeScriptプロジェクト向けの追加分析も行いますか？（複数選択可）",
  "multiSelect": true,
  "options": [
    { "label": "型安全性", "description": "any型が残っている箇所を検出する" },
    { "label": "コード品質", "description": "アンチパターン・フレームワーク固有の問題" }
  ]
}
```

### Otherで自由記述が入った場合の解釈

| キーワード例 | 対応する観点 |
|---|---|
| 重たい・遅い・パフォーマンス | ホットスポット |
| テストが書きにくい・テストできない | 構造・依存関係 |
| 特定ファイルに変更が集中・繰り返し直している | ホットスポット + temporal coupling |
| 不要・使われていない・ゴミが多い | デッドコード削減 |
| any・型・TypeScript | 型安全性 |
| 読みにくい・わかりにくい・命名 | コード品質 |
| 依存関係・import・循環・複雑 | 構造・依存関係 |

解釈した結果を「〇〇と〇〇の観点で分析します」と明示してからStep 3に進みます。

## Step 3: hotspot-analyzer エージェントを起動する

`Agent`ツールで`hotspot-analyzer`エージェントを起動し、Step 1・Step 2で決めた値を渡します。

```
Agent: hotspot-analyzer
引数:
- TARGET_DIR: <対象ディレクトリ>
- 観点: <指定された観点（Otherの解釈結果を含む）>
- IS_TS: <true / false>
- SINCE: <期間（デフォルト 12.month）>
```

エージェントはgit履歴・構造・コード品質を分析し、優先度（P1 / P2 / P3）付きのリファクタリング提案を返します。

`hotspot-analyzer`が起動できない場合は、その旨を伝え、エージェントの定義（`agents/hotspot-analyzer.md`）にしたがって手動で分析します。

## Step 4: 提案を提示する

エージェントが返した提案（分析サマリー・P1〜P3の候補・観点別の補足・免責事項）をそのままユーザーに提示します。提案はリファクタリングの候補であり、実施の判断はユーザーに委ねます。
