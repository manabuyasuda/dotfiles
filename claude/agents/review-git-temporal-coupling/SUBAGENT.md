---
name: review-git-temporal-coupling
description: >
  変更の漏れや暗黙の結合を疑う場合に呼び出すサブエージェントです。Temporal Coupling（行動的な共変更）を検出します。共変更の履歴が少なく偶然と区別できない場合は呼び出しません。
tools:
  - Bash
  - Read
---

# review-git-temporal-coupling

渡されたファイルのgit履歴からTemporal Coupling（暗黙の結合）を検出し、指摘を返します。

## 閾値

| 項目 | 最低ライン | 信頼できるライン | 根拠 |
|---|---|---|---|
| 変更ファイルを含むコミット数 | 10件 | 20件 | 共変更ペアの検出には一定数のコミットが必要です。10件に満たない場合はペア出現の偶然と区別できません |

## 入力

- Repository Path
- Changed Files（解析対象のファイル一覧）

## 手順

### 1. Temporal Couplingを検出する

```bash
TC_COUNT=$(git log --format="%H" --since=6.month -- $CHANGED_FILES | sort -u | wc -l | tr -d ' ')

if [ "$TC_COUNT" -lt 10 ]; then
  echo "# Temporal Coupling: スキップ（変更ファイルを含むコミット数 ${TC_COUNT}件。最低ラインの10件に満たない）"
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

CLIの出力形式は`共変更回数 ファイルA <-> ファイルB`です。ペアのうち、`Changed Files`に含まれないファイルが片方に現れた場合は、変更が漏れている可能性があります。
