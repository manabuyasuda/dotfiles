---
disable-model-invocation: true
name: x-code-review-git-history
description: git履歴からコードの設計的な不安定さを分析するレビューを実施します。ホットスポットスコア・書き換え率・Temporal Couplingの3つを統合し、変更規模が最低ラインに満たない分析はスキップします。「git履歴を分析して」「ホットスポットを見て」「history review」のように使います。静的解析ツールの実行はx-code-review-static、AIの判断によるレビューはx-code-review-judgmentが担当します。
context: fork
allowed-tools:
  - Bash
  - Read
  - Glob
  - Grep
---

# git履歴レビュー

git履歴はファイルの「設計的な不安定さの蓄積」を示します。変更ファイルがもともとホットスポットかどうかを把握することで、レビューの深度と設計指摘の優先度を正しく判断できます。

## Step 1: 変更ファイルを確定する

```bash
CURRENT_BRANCH=$(git branch --show-current)
BASE_BRANCH=$(git remote show origin | awk '/HEAD branch/ {print $NF}')
CHANGED_FILES=$(git diff --name-only origin/${BASE_BRANCH}...HEAD)
```

引数にPR番号がある場合は`gh pr diff <番号> --name-only`で確定します。

## Step 2: 最低ラインを判定する

各分析には一定のコミット数が必要です。最低ラインに満たない分析はスキップし、スキップした理由を結果に明記します。最低ライン以上・信頼できるライン未満の場合は結果に`[低精度]`を付加して出力します。

| 分析 | 最低ライン | 信頼できるライン | 対象単位 |
|---|---|---|---|
| ホットスポットスコア | 5回 | 10回 | ファイルごとのコミット回数 |
| 書き換え率 | 10回 | 20回 | ファイルごとのコミット回数 |
| Temporal Coupling | 10件 | 20件 | 変更ファイルを含むコミット総数 |

3つの分析すべてが最低ラインに満たない場合は、「変更規模が小さくgit履歴の分析対象になりません」と報告してレビューを終了します。

## Step 3: 3つの分析を実行する

### ホットスポットスコア（変更頻度 × 行数）

変更頻度が高く行数も多いファイルは「複雑なのに頻繁に触られる」ホットスポットです。今回の変更が問題をさらに悪化させていないかを重点的にレビューする判断材料にします。

```bash
for f in $CHANGED_FILES; do
  [ -f "$f" ] || continue
  count=$(git log --format=format: --name-only --since=12.month -- "$f" | grep -v '^\s*$' | wc -l | tr -d ' ')
  lines=$(wc -l < "$f" | tr -d ' ')
  if [ "$count" -lt 5 ]; then
    continue
  elif [ "$count" -lt 10 ]; then
    echo "$((count * lines)) $count $lines $f [低精度: 変更回数${count}回]"
  else
    echo "$((count * lines)) $count $lines $f"
  fi
done | grep -v '^$' | sort -nr
```

出力形式は`スコア 変更回数 行数 ファイルパス`です。

### 書き換え率（削除率）

削除率が50%超のファイルは、「書いては消す」が繰り返されていて設計が不安定であることを示すシグナルです。今回の変更がその傾向をさらに強めていないかを確認します。

最低ライン（10回）以上のファイルのみを対象にし、信頼できるライン（20回）未満のファイルは注意付きで出力します。

```bash
REWRITE_TARGET=""
REWRITE_WARN=""
for f in $CHANGED_FILES; do
  [ -f "$f" ] || continue
  count=$(git log --format=format: --name-only --since=12.month -- "$f" | grep -v '^\s*$' | wc -l | tr -d ' ')
  if [ "$count" -ge 10 ]; then
    REWRITE_TARGET="$REWRITE_TARGET $f"
    [ "$count" -lt 20 ] && REWRITE_WARN="$REWRITE_WARN $f(${count}回)"
  fi
done

if [ -n "$REWRITE_TARGET" ]; then
  git log --numstat --format=format: --since=12.month -- $REWRITE_TARGET \
    | grep -v '^\s*$' \
    | awk '{add[$3]+=$1; del[$3]+=$2} END {
        for(f in add) {
          total=add[f]+del[f];
          if(total>0)
            print int(del[f]/total*100) "% " total " " del[f] " " f
        }
      }' \
    | sort -nr
  [ -n "$REWRITE_WARN" ] && echo "[低精度] 信頼できるライン（20回）未満: $REWRITE_WARN"
else
  echo "# 書き換え率: スキップ（最低ライン10回を満たすファイルなし）"
fi
```

出力形式は`削除率 総変更行数 削除行数 ファイルパス`です。

### Temporal Coupling（暗黙の結合検出）

変更ファイルを起点に「常にペアで変更されるファイル」を検出します。今回の変更に含まれていないファイルがペアとして出現したときは、変更の見落とし（または暗黙の結合）の可能性があります。静的な依存関係がなくても行動的に結合しているファイルを発見できます。

```bash
TC_COUNT=$(git log --format="%H" --since=6.month -- $CHANGED_FILES | sort -u | wc -l | tr -d ' ')

if [ "$TC_COUNT" -lt 10 ]; then
  echo "# Temporal Coupling: スキップ（変更ファイルを含むコミット数 ${TC_COUNT}件: 最低ライン10件未満）"
else
  git log --format=format: --name-only --since=6.month -- $CHANGED_FILES \
    | awk '
      /^$/ { for(i in files) for(j in files) if(i<j) pairs[i" <-> "j]++; delete files; next }
      /[^ ]/ { files[$0]=1 }
      END { for(p in pairs) if(pairs[p]>2) print pairs[p], p }
    ' | sort -nr | head -20
  [ "$TC_COUNT" -lt 20 ] && echo "[低精度] 変更ファイルを含むコミット数 ${TC_COUNT}件（信頼できるライン: 20件以上）"
fi
```

出力形式は`共変更回数 ファイルA <-> ファイルB`です。

## Step 4: 結果を統合して出力する

3つの分析結果から、レビューに影響する情報のみを出力します。シグナルが何もない場合は「シグナルなし」と1行で報告します。

```
## git履歴コンテキスト

**ホットスポット**（変更頻度が高く行数も多いファイル）
- <ファイルパス>: スコア<N>（変更<N>回 / <N>行）

**書き換え率が高いファイル**（削除率50%超）
- <ファイルパス>: 削除率<N>%

**Temporal Coupling（変更漏れ候補）**
- <ファイルA> <-> <ファイルB>: <N>回のコミットで共変更 ※今回の変更に<ファイルB>が含まれていない

**スキップした分析**
- <分析名>: <理由>
```

分析結果の解釈は次の基準で添えます。

- ホットスポットスコアが高いファイルに新たにロジックを追加している場合は、責務の肥大化を確認する対象として提示します
- 書き換え率が50%超のファイルへの変更は、同じ「書いては消す」パターンの繰り返しになっていないかを確認する対象として提示します
- Temporal Couplingのペアのうち今回の変更に含まれないファイルは、変更の見落としか意図的な除外かを確認する対象として提示します
