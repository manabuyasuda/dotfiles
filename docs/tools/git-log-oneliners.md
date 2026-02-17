# git logワンライナー集

git logの出力をパイプで加工し、リポジトリの変更履歴からコードの健全性やリスクを分析するワンライナー集。外部ツール不要で、gitだけで実行できる。

## 背景: Hotspot分析とcode-maat

このワンライナー集は、Adam Tornhillの著書『Your Code as a Crime Scene』の考え方に基づいている。同書の分析ツール[code-maat](https://github.com/adamtornhill/code-maat)はGitログを入力として以下の分析を行う。

| 分析 | 内容 |
|------|------|
| Change frequency（変更頻度） | どのファイルが最も頻繁に変更されるか |
| Temporal coupling（時間的結合） | いつも一緒に変更されるファイルのペア（暗黙の依存関係） |
| Author analysis（著者分析） | 特定のファイルの知識が一人に集中していないか（バス係数） |

**Hotspot分析**はこの変更頻度に**ファイルの複雑度**（行数やインデンテーション深度）を掛け合わせたもの。「よく変更される x 複雑」なファイルこそがバグが潜みやすく、リファクタリングの投資対効果が最も高い箇所（＝ホットスポット）という考え方。

以下のワンライナーは、code-maatの主要な分析をgitコマンドだけで簡易的に再現するもの。

## 変更頻度の分析（← code-maatのChange frequency相当）

### 変更頻度トップファイル（ホットスポット）

```bash
git log --format=format: --name-only --since=12.month \
  | egrep -v '^\s*$' \
  | sort \
  | uniq -c \
  | sort -nr \
  | head -50
```

出力形式: `変更回数 ファイルパス`

```
   5 Brewfile
   4 docs/tools/README.md
   3 setup.sh
```

過去12ヶ月で最も頻繁に変更されたファイルを一覧する。上位に来るファイルは仕様変更の波が来ているか、設計に問題がある可能性がある。

### 変更頻度 x ファイルサイズ（簡易ホットスポットスコア）

```bash
git log --format=format: --name-only --since=12.month \
  | egrep -v '^\s*$' | sort | uniq -c | sort -nr | head -50 \
  | while read count file; do
      if [ -f "$file" ]; then
        lines=$(wc -l < "$file")
        score=$((count * lines))
        echo "$score $count $lines $file"
      fi
    done | sort -nr | head -20
```

出力形式: `スコア 変更回数 行数 ファイルパス`

```
366 3 122 setup.sh        ← 3回変更 x 122行 = スコア366
360 4  90 docs/tools/README.md
180 5  36 Brewfile
```

「変更回数 x 行数 = ホットスポットスコア」。code-maatのHotspot分析の簡易版で、よく変更される上に複雑（行数が多い）ファイルを特定する。リファクタリングの投資対効果が最も高い箇所。

## Code churn（コードチャーン）

### ファイルごとの総変更行数

```bash
git log --numstat --format=format: --since=12.month \
  | egrep -v '^\s*$' \
  | awk '{add[$3]+=$1; del[$3]+=$2} END {for(f in add) printf "%d %d %d %s\n", add[f]+del[f], add[f], del[f], f}' \
  | sort -nr | head -20
```

出力形式: `総変更行数 追加行数 削除行数 ファイルパス`

```
520 380 140 src/components/Dashboard.tsx
310 200 110 src/api/client.ts
 85  85   0 src/utils/format.ts
```

追加行数と削除行数の両方が多いファイルは、書き直しが繰り返されている＝設計が安定していない。追加だけが多いファイル（削除が0に近い）は単純な機能追加なので問題ない。

### 書き換え率が高いファイル（不安定度）

```bash
git log --numstat --format=format: --since=12.month \
  | egrep -v '^\s*$' \
  | awk '{add[$3]+=$1; del[$3]+=$2} END {for(f in add) {total=add[f]+del[f]; if(total>20 && del[f]>0) printf "%.0f%% %d %d %d %s\n", del[f]/total*100, total, add[f], del[f], f}}' \
  | sort -nr | head -20
```

出力形式: `削除率 総変更行数 追加行数 削除行数 ファイルパス`

```
65% 520 182 338 src/api/client.ts    ← 変更の65%が削除＝大幅な書き換え
42% 310 180 130 src/hooks/useAuth.ts
```

削除率が高い（50%超）ファイルは、追加してはすぐ消すという不安定な変更が繰り返されている。設計の見直し候補。

## 複雑度の推移

### 純増行数が多いファイル（肥大化の兆候）

```bash
git log --numstat --format=format: --since=12.month \
  | egrep -v '^\s*$' \
  | awk '{add[$3]+=$1; del[$3]+=$2} END {for(f in add) {net=add[f]-del[f]; if(net>0) printf "%d %d %d %s\n", net, add[f], del[f], f}}' \
  | sort -nr | head -20
```

出力形式: `純増行数 追加行数 削除行数 ファイルパス`

```
240 380 140 src/components/Dashboard.tsx  ← 12ヶ月で240行増加
 90 200 110 src/api/client.ts
```

純増行数が大きいファイルは肥大化している。ホットスポットスコアと組み合わせて、「頻繁に変更される上に肥大化している」ファイルがリファクタリングの最優先候補。

### 特定ファイルの行数推移

```bash
FILE="src/components/Dashboard.tsx"
git log --format='%H %as' --since=12.month -- "$FILE" \
  | while read hash date; do
      lines=$(git show "$hash:$FILE" 2>/dev/null | wc -l)
      echo "$date $lines"
    done
```

出力形式: `日付 行数`

```
2025-12-15 520
2025-10-03 480
2025-07-20 350
2025-03-10 280
```

特定ファイルの行数が時系列でどう推移しているかを確認する。急激な増加があった時期をコミットログと突き合わせることで、肥大化の原因を特定できる。

### インデンテーション深度（ネストの複雑さ）

```bash
git ls-files '*.ts' '*.tsx' | while read file; do
  lines=$(wc -l < "$file")
  avg_indent=$(awk '{match($0, /^[ \t]*/); total+=RLENGTH; count++} END {if(count>0) printf "%.1f", total/count}' "$file")
  echo "$avg_indent $lines $file"
done | sort -nr | head -20
```

出力形式: `平均インデント深度 行数 ファイルパス`

```
8.5 520 src/components/Dashboard.tsx  ← 平均8.5文字分のインデント
6.2 310 src/api/client.ts
3.1  85 src/utils/format.ts
```

行数だけでは捉えられない「ネストの深さ」を可視化する。平均インデントが深いファイルは条件分岐やコールバックが多く、認知的な複雑さが高い。`'*.ts' '*.tsx'` の部分を変えれば対象言語を変更できる。行数と掛け合わせると、code-maatのHotspot分析に近い複雑度指標になる。

## Temporal Coupling（← code-maatのTemporal coupling相当）

### 一緒にコミットされがちなファイルペア

```bash
git log --format=format: --name-only --since=6.month \
  | awk '
    /^$/ { for(i in files) for(j in files) if(i<j) pairs[i" <-> "j]++; delete files; next }
    /[^ ]/ { files[$0]=1 }
    END { for(p in pairs) if(pairs[p]>3) print pairs[p], p }
  ' | sort -nr | head -20
```

出力形式: `共変更回数 ファイルA <-> ファイルB`

```
5 src/api/client.ts <-> src/hooks/useAuth.ts
4 src/types/user.ts <-> src/api/client.ts
```

常にペアで変更されるファイルは、本来一つのモジュールにまとめるべきか、インターフェースの設計に問題がある可能性がある。静的解析では見つからない依存関係を検出できる。`pairs[p]>3` の閾値は小規模リポジトリでは `>1` に下げるとよい。

### 特定ディレクトリ間の結合度

```bash
git log --format=format: --name-only --since=6.month \
  | awk '
    /^$/ {
      has_a=0; has_b=0
      for(f in files){ if(f~/^src\/components/) has_a=1; if(f~/^src\/api/) has_b=1 }
      if(has_a && has_b) both++
      if(has_a) a++
      delete files; next
    }
    /[^ ]/ {files[$0]=1}
    END { printf "components変更: %d回\nそのうちapiも同時変更: %d回 (%.0f%%)\n", a, both, both/a*100 }
  '
```

出力形式:

```
components変更: 30回
そのうちapiも同時変更: 12回 (40%)
```

ディレクトリ名を変えれば任意のレイヤー間の結合度を測れる。割合が高いならレイヤー間の抽象化が不十分。

## バグ・品質リスクの分析

### バグ修正が集中するファイル

```bash
git log --grep="fix\|bug" -i --format=format: --name-only --since=12.month \
  | egrep -v '^\s*$' | sort | uniq -c | sort -nr | head -20
```

出力形式: `修正回数 ファイルパス`（ホットスポットと同じ形式）

バグ修正が繰り返されるファイルは根本的な設計問題を抱えている可能性が高い。

### revertが多いファイル（不安定な変更の指標）

```bash
git log --oneline --since=6.month --grep="revert" -i \
  --format=format: --name-only \
  | egrep -v '^\s*$' | sort | uniq -c | sort -nr
```

出力形式: `revert回数 ファイルパス`（ホットスポットと同じ形式）

### 巨大コミットの検出

```bash
git log --oneline --since=6.month \
  | while read hash msg; do
      count=$(git diff-tree --no-commit-id --name-only -r "$hash" | wc -l)
      echo "$count $hash $msg"
    done | sort -nr | head -20
```

出力形式: `変更ファイル数 コミットハッシュ コミットメッセージ`

```
17 395ea8b docs: 各開発ツールの説明ページを追加
 7 59ac449 feat: gh拡張機能5種を追加し各ドキュメントを作成
 1 993ab4c docs: READMEを追加
```

一度に数十ファイル変更しているコミットは、レビューが不十分だった可能性やビッグバンリリースのリスクを示唆する。ただし新規ファイルの一括追加は問題ない。既存コードの大量変更に注目する。

### コードの年齢（最終更新からの経過日数）

```bash
git ls-files '*.ts' '*.tsx' | while read file; do
  last=$(git log -1 --format='%at' -- "$file")
  now=$(date +%s)
  days=$(( (now - last) / 86400 ))
  lines=$(wc -l < "$file")
  echo "$days $lines $file"
done | sort -nr | head -20
```

出力形式: `経過日数 行数 ファイルパス`

```
385 520 src/legacy/parser.ts     ← 1年以上放置 x 520行
210 310 src/utils/deprecated.ts
 90  85 src/api/client.ts
```

長期間変更されていない上に行数が多いファイルは、理解されにくく触ると壊れやすい。経過日数と行数の両方が大きいファイルは技術的負債の候補。

### モジュール単位のバグ密度

```bash
git log --grep="fix\|bug" -i --format=format: --name-only --since=12.month \
  | egrep -v '^\s*$' \
  | awk -F/ '{if(NF>=2) print $1"/"$2; else print $1}' \
  | sort | uniq -c | sort -nr | head -20
```

出力形式: `修正回数 ディレクトリ`

```
18 src/components
12 src/api
 5 src/hooks
 2 src/utils
```

ファイル単位ではなくディレクトリ（モジュール）単位でバグ修正を集計する。特定のモジュールに修正が集中していれば、そのモジュール全体の設計を見直す判断材料になる。`-F/` のフィールド数を変えれば集計の粒度を調整できる。

## 人・チームの分析（← code-maatのAuthor analysis相当）

### ファイルごとの著者数（知識の分散度）

```bash
git log --format='%aN' --since=12.month -- src/ \
  | sort | uniq -c | sort -nr
```

出力形式: `コミット数 著者名`

```
 42 alice
 15 bob
  3 charlie
```

`-- src/` の部分を変えれば対象ディレクトリを絞れる。特定の人しか触っていないファイルはバス係数のリスクがある。

### コミットの曜日・時間帯分布

```bash
git log --format='%aD' --since=6.month \
  | awk '{print $1}' | sort | uniq -c | sort -nr
```

出力形式: `コミット数 曜日`

```
  12 Fri,
   8 Thu,
   7 Mon,
```

金曜夕方にコミットが集中していたらデプロイリスクの指標になる。

### 所有者の分散（ファイルごとの著者数）

```bash
git ls-files '*.ts' '*.tsx' | while read file; do
  authors=$(git log --format='%aN' --since=12.month -- "$file" | sort -u | wc -l)
  echo "$authors $file"
done | sort -nr | head -20
```

出力形式: `著者数 ファイルパス`

```
 8 src/components/Dashboard.tsx  ← 8人が触っている
 6 src/api/client.ts
 1 src/utils/legacy.ts           ← 1人だけが知っている
```

著者数が多すぎるファイルは責任が曖昧になりやすい。逆に1人しか触っていないファイルはバス係数のリスクがある。チームの知識分布を把握し、ペアプログラミングやレビューの優先度を判断する材料になる。

## まとめて分析する

複数の分析結果をファイルに保存してまとめて確認すると、立体的な分析ができる。

```bash
echo "=== HOTSPOTS ===" > analysis.txt
git log --format=format: --name-only --since=12.month \
  | egrep -v '^\s*$' | sort | uniq -c | sort -nr | head -50 >> analysis.txt

echo -e "\n=== BUG FIX CONCENTRATION ===" >> analysis.txt
git log --grep="fix\|bug" -i --format=format: --name-only --since=12.month \
  | egrep -v '^\s*$' | sort | uniq -c | sort -nr | head -20 >> analysis.txt

echo -e "\n=== TEMPORAL COUPLING ===" >> analysis.txt
git log --format=format: --name-only --since=6.month \
  | awk '
    /^$/ { for(i in files) for(j in files) if(i<j) pairs[i" <-> "j]++; delete files; next }
    /[^ ]/ { files[$0]=1 }
    END { for(p in pairs) if(pairs[p]>3) print pairs[p], p }
  ' | sort -nr | head -20 >> analysis.txt
```

この出力をClaude Codeに渡すと、ホットスポット・バグ集中箇所・隠れた依存関係を踏まえた構造的なリファクタリング提案が可能になる。

## 参考リンク

- [Your Code as a Crime Scene (Adam Tornhill)](https://pragprog.com/titles/atcrime2/your-code-as-a-crime-scene-second-edition/)
- [code-maat](https://github.com/adamtornhill/code-maat)
