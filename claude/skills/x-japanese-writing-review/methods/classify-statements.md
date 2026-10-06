<!-- textlint-disable @textlint-ja/ai-writing/no-ai-list-formatting, @textlint-ja/ai-writing/no-ai-hype-expressions, @textlint-ja/ai-writing/ai-tech-writing-guideline, ja-technical-writing/ja-no-redundant-expression, ja-technical-writing/max-ten, ja-technical-writing/no-doubled-joshi, ja-technical-writing/no-doubled-conjunctive-particle-ga, ja-technical-writing/ja-no-successive-word, ja-technical-writing/sentence-length, prh -->

# 文の内容を、観察できる事実・推測・評価に分ける手順

読み手が、どこまでを確かめられた内容として扱えるかを判定します。

## 手順

1. 同じディレクトリの`split-into-elements.md`の手順で、文を述語・要素・文の働きに分けます
2. 述語と要素ごとに、次のどれに当たるかを決めます
   - 観察できる事実：数値・日時・実行結果・引用のように、読み手が同じ方法で確かめられる内容
   - 推測：観察した事実から書き手が導いた内容。原因・理由・見通しのうち、確かめた方法が文書に書かれていないものは、断定の形で書かれていても推測とします
   - 評価：「重要な」「十分に」「適切に」「非常に」のように、基準を示さずに良し悪しや程度を述べる語
3. 推測に当たる要素は、「〜と考えられます」「〜の可能性があります」のような、推測だとわかる語で書かれているかを書き出します
4. 評価に当たる要素は、評価の基準になる観察できる事実が、同じ文書に書かれているかを書き出します
5. 文書の外の事実（文書内のコード・設定・実行結果で確かめられないもの）を述べる要素は、出典が書かれているかを書き出します。「専門家によると」のように、誰を指すか特定できない主体は、出典として扱いません

## 書き出す形式

| 要素 | 種類 | 推測だとわかる語があるか | 評価の基準があるか | 出典があるか |
|---|---|---|---|---|

当てはまらない列は「―」とします。
