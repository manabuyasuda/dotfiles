---
name: hotspot-refactoring
description: >
  git logのhotspot分析・循環参照・デッドコード・不安定性メトリクスを組み合わせて
  リファクタリング優先候補を提案する。「hotspot」「リファクタリング提案して」
  「どこを直すべき」「技術的負債を調べて」のように使う。
context: fork
allowed-tools:
  - Bash
  - Read
  - Glob
  - Grep
---

# hotspot-refactoring

## 概要

**目的**: git履歴・静的解析・依存関係分析を組み合わせ、リファクタリング投資対効果がもっとも高い箇所を特定して提案する。

**フロー**: スコープ確認 → 観点確認 → 分析実行 → クロスリファレンス → 優先度付き提案出力

---

## 実行手順

### Step 1: スコープを確認する

以下を質問する:

```
リファクタリング分析の対象範囲を教えてください。

対象ディレクトリ（複数可）:
  例: プロジェクト全体 / src/features/ / packages/api（モノレポ）

あわせて確認します:
  - 主な言語・フレームワーク（TypeScript / JavaScript / その他）
  - git分析の対象期間（デフォルト: 過去12ヶ月）
```

回答から以下の変数を決定する:

- `TARGET_DIR`: 分析対象ディレクトリ（未指定の場合は `.`）
- `IS_TS`: TypeScript/JSプロジェクトか（Madge・Knip・type-coverageの使用可否）
- `SINCE`: git分析の期間（デフォルト: `12.month`）

---

### Step 2: リファクタリングの観点を確認する

以下を質問する:

```
どのような観点でリファクタリング候補を探しますか？
番号で選ぶか、気になっていることを自由に教えてください（複数可）。

  1. ホットスポット    — 頻繁に変更される・複雑なファイルを特定する
  2. 構造・依存関係   — 循環参照・隠れた結合・アーキテクチャ違反
  3. デッドコード削減  — 未使用ファイル・未使用エクスポート
  4. 型安全性         — any型が残っている箇所（TypeScriptプロジェクト）
  5. コード品質       — アンチパターン・フレームワーク固有の問題
  6. お任せ           — すべての観点で分析

自由記述の例:
  「なんか重たくなってきた」
  「テストが書きにくい」
  「特定のモジュールに変更が集中している気がする」
  「依存関係がぐちゃぐちゃになってきた」
```

#### 自由記述の解釈方針

自由記述を受け取った場合、以下の指針でツールの組み合わせに変換する:

| キーワード例 | 対応する観点 |
|---|---|
| 重たい・遅い・パフォーマンス | 1（ホットスポット） |
| テストが書きにくい・テストできない | 2（循環参照・構造） |
| 特定ファイルに変更が集中・繰り返し直している | 1（ホットスポット + temporal coupling） |
| 不要・使われていない・ゴミが多い | 3（デッドコード） |
| any・型・TypeScript | 4（型安全性） |
| 読みにくい・わかりにくい・命名 | 5（コード品質） |
| 依存関係・import・循環・複雑 | 2（構造） |
| 全部・わからない・お任せ | 6（すべて） |

解釈した結果を「〇〇と〇〇の観点で分析します」と明示してからStep 3に進む。

---

### Step 3: Phase 1 — どこに問題があるかを特定する（git履歴分析）

観点に **1・6** が含まれる場合、または自由記述から関連すると判断した場合に実行する。

#### 3-1. 変更頻度 × ファイルサイズ（ホットスポットスコア）

```bash
git log --format=format: --name-only --since=<SINCE> -- <TARGET_DIR> \
  | grep -v '^\s*$' | sort | uniq -c | sort -nr | head -50 \
  | while read count file; do
      if [ -f "$file" ]; then
        lines=$(wc -l < "$file")
        score=$((count * lines))
        echo "$score $count $lines $file"
      fi
    done | sort -nr | head -20
```

出力形式: `スコア 変更回数 行数 ファイルパス`

#### 3-2. 書き換え率が高いファイル（設計の不安定性）

```bash
git log --numstat --format=format: --since=<SINCE> -- <TARGET_DIR> \
  | grep -v '^\s*$' \
  | awk '{add[$3]+=$1; del[$3]+=$2} END {
      for(f in add) {
        total=add[f]+del[f];
        if(total>20 && del[f]>0)
          printf "%.0f%% %d %d %d %s\n", del[f]/total*100, total, add[f], del[f], f
      }
    }' \
  | sort -nr | head -20
```

出力形式: `削除率 総変更行数 追加行数 削除行数 ファイルパス`

削除率50%超は「書いては消す」が繰り返されている設計の不安定シグナル。

#### 3-3. バグ修正が集中するファイル

```bash
git log --grep="fix\|bug" -i --format=format: --name-only --since=<SINCE> -- <TARGET_DIR> \
  | grep -v '^\s*$' | sort | uniq -c | sort -nr | head -20
```

#### 3-4. Temporal Coupling（常にペアで変更されるファイル）

```bash
git log --format=format: --name-only --since=6.month -- <TARGET_DIR> \
  | awk '
    /^$/ { for(i in files) for(j in files) if(i<j) pairs[i" <-> "j]++; delete files; next }
    /[^ ]/ { files[$0]=1 }
    END { for(p in pairs) if(pairs[p]>2) print pairs[p], p }
  ' | sort -nr | head -20
```

出力形式: `共変更回数 ファイルA <-> ファイルB`

常にペアで変更されるのに静的依存がないファイルは隠れた結合のシグナル。

結果を「ホットスポットランキング」として内部に保持する。

---

### Step 4: Phase 2 — 構造的問題を検出する

#### 4-1. 循環参照（IS_TSの場合）

観点に **2・6** が含まれる場合に実行する。

```bash
# tsconfig.jsonが存在する場合
madge --circular --ts-config tsconfig.json <TARGET_DIR> 2>/dev/null

# tsconfig.jsonが存在しない場合
madge --circular <TARGET_DIR> 2>/dev/null
```

tsconfig.jsonの有無は `Glob` で確認してから実行する。

#### 4-2. 依存数サマリー（依存数が多いファイル）

観点に **2・6** が含まれる場合に実行する。

```bash
madge --summary <TARGET_DIR> 2>/dev/null | sort -t: -k2 -nr | head -20
```

依存数が多いファイルは変更リスクが高く、分割検討対象。

#### 4-3. デッドコード検出

観点に **3・6** が含まれる場合に実行する。IS_TSの場合はKnipを優先し、失敗した場合はMadgeで代替する。

```bash
# IS_TSの場合: Knip優先
knip --reporter compact 2>/dev/null

# Knipが失敗した場合、またはIS_TSでない場合: Madgeで孤立ファイルを検出
madge --orphans <TARGET_DIR> 2>/dev/null
```

Knipはプロジェクトに設定ファイル（`knip.config.*` または `package.json` の `knip` フィールド）がないと誤検知が多い。大量出力またはエラーの場合はMadgeに切り替える。

#### 4-4. 安定性メトリクス（不安定モジュールの検出）

観点に **2・6** が含まれる場合に実行する。

```bash
depcruise --metrics -T metrics <TARGET_DIR> 2>/dev/null | head -40
```

不安定性指数（I = Ce/(Ca+Ce)）が高いのに多くから依存されているモジュールはもっともリスクが高い。

---

### Step 5: Phase 3 — コード品質を検出する

#### 5-1. アンチパターン検出（Semgrep）

観点に **5・6** が含まれる場合に実行する。IS_TSに応じてルールセットを選択する。

```bash
# TypeScript/JSの場合
semgrep scan --config p/typescript --config p/react \
  --severity=ERROR --severity=WARNING \
  --no-rewrite-rule-ids \
  <TARGET_DIR> 2>/dev/null

# その他の場合
semgrep scan --config auto \
  --severity=ERROR --severity=WARNING \
  <TARGET_DIR> 2>/dev/null
```

Semgrepはルールセット取得にネットワークアクセスが必要。失敗した場合はスキップしてその旨を記載する。

#### 5-2. 型カバレッジ（type-coverage）

観点に **4・6** が含まれ、IS_TSがtrueの場合に実行する。

```bash
type-coverage --detail --strict \
  --ignore-catch --ignore-nested --ignore-as-assertion \
  --show-relative-path 2>/dev/null | head -50
```

---

### Step 6: クロスリファレンスして優先度付きで提案を出力する

収集したすべての分析結果を突き合わせ、以下の優先度で分類する。

#### 優先度の判定基準

| Priority | 条件 |
|---|---|
| P1: 最優先 | 複数のシグナルが重なるファイル（例: ホットスポット上位 かつ 循環参照あり） |
| P2: 高優先 | 単一のシグナルだが深刻（例: 循環参照があるが変更頻度は低い） |
| P3: Quick Win | 削除・整理だけで完結するもの（未使用ファイル・未使用エクスポート） |

#### クロスリファレンスの例

- ホットスポット上位 × 循環参照あり →「頻繁に変更されるのにテストが書きにくい」最悪のケース
- Temporal Coupling（A↔Bが常にペア）× Madgeで依存なし →「静的には独立しているのに行動的には結合している」
- 不安定性指数が高い × 多くのモジュールから依存される →「安定しているべきモジュールが不安定」
- バグ修正集中 × Semgrepでアンチパターン検出 →「設計の問題がバグとして出続けている」

#### 出力フォーマット

```
## リファクタリング提案

### 分析サマリー
- 対象: <TARGET_DIR>
- 期間: 過去<SINCE>
- 観点: <指定された観点（自由記述の場合は解釈結果も記載）>

---

### P1: 最優先候補

**<ファイルパス>**
- シグナル: <検出されたシグナルを列挙（例: ホットスポットスコア 1240 / 循環参照あり / バグ修正5回）>
- 問題: <何が問題か、なぜ問題か>
- 提案: <具体的なリファクタリング手法（責務分割・インターフェース抽出・循環解消の方向性など）>

...

---

### P2: 高優先候補

...

---

### P3: Quick Win（削除・整理で即完結）

- `<ファイルパス>` — 未使用ファイル（knip検出）
- `<エクスポート名>` in `<ファイルパス>` — 未使用エクスポート

...

---

### 観点別の補足

<指定された観点ごとの追加所見・注意点>

---

### 免責事項

上記はコードの変更履歴と静的解析に基づく機械的な候補です。
ビジネスコンテキスト・チームの優先事項・リリース計画に照らして判断してください。
```

---

## 注意事項

- Madge・Knip・type-coverageはJS/TSプロジェクト専用。他の言語ではPhase 2のこれらをスキップし、git分析とSemgrepのみで対応する
- git履歴が浅いリポジトリ（shallow clone）では変更頻度分析の精度が低下する。その場合は `git log --oneline | wc -l` でコミット数を確認してユーザーに伝える
- Semgrepはネットワークアクセスが必要。オフライン環境では `--config auto` が失敗するためスキップする
- Knipは設定ファイルがないプロジェクトでは誤検知が多い。大量出力（100件超）またはエラーの場合はMadge `--orphans` に切り替える
- 提案はリファクタリングの候補であり、実施の判断はユーザーに委ねる
