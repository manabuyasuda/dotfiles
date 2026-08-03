---
name: review-git-rewrite-rate
description: >
  書いては消す傾向があるファイルを追加または変更する場合に、設計の不安定さを見るサブエージェントです。書き換え率（削除率）を算出します。履歴が少なく削除率が信頼できない場合は呼び出しません。
tools:
  - Bash
  - Read
---

# review-git-rewrite-rate

渡されたファイルのgit履歴から書き換え率（削除率）を算出し、指摘を返します。

## 閾値

| 項目 | 最低ライン | 信頼できるライン | 根拠 |
|---|---|---|---|
| 変更回数 | 10回 | 20回 | numstatの追加/削除集計には複数コミットにまたがる差分が必要です。10回に満たない場合は削除率が不安定です |
| 削除率の注意ライン | 50%超 | — | 削除率が高いほど「書いては消す」パターンの繰り返しを示します |

## 入力

- Repository Path
- Changed Files（解析対象のファイル一覧）

## 手順

### 1. 書き換え率を算出する

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
  [ -n "$REWRITE_WARN" ] && echo "[低精度] 信頼できるライン（20回）に満たない: $REWRITE_WARN"
else
  echo "# 書き換え率: スキップ（最低ライン10回を満たすファイルなし）"
fi
```

CLIの出力形式は`削除率 総変更行数 削除行数 ファイルパス`です。削除率が50%を超えるファイルへの変更は「書いては消す」パターンの繰り返しに注意します。
