# git logワンライナー集

git logの出力をパイプで加工し、リポジトリの変更履歴からコードの健全性やリスクを分析するワンライナー集。外部ツール不要で、gitだけで実行できる。

## 変更頻度の分析

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

「変更回数 x 行数 = ホットスポットスコア」。よく変更される上に複雑（行数が多い）ファイルを特定する。リファクタリングの投資対効果が最も高い箇所。

## Temporal Coupling（暗黙の結合）

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

## 人・チームの分析

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
