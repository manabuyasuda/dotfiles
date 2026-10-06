<!-- textlint-disable @textlint-ja/ai-writing/no-ai-list-formatting, @textlint-ja/ai-writing/no-ai-hype-expressions, @textlint-ja/ai-writing/ai-tech-writing-guideline, ja-technical-writing/ja-no-redundant-expression, ja-technical-writing/max-ten, ja-technical-writing/no-doubled-joshi, ja-technical-writing/no-doubled-conjunctive-particle-ga, ja-technical-writing/ja-no-successive-word, ja-technical-writing/sentence-length, prh -->

# 読み手が行動や採否を決めるのに必要な要素が、欠けていないかを判定する手順

文の働きごとに必要な要素を決め、文と文書に書かれているかを確かめます。

## 手順

1. 同じディレクトリの`split-into-elements.md`の手順で、文を述語・要素・文の働きに分けます
2. 文の働きに応じて、必要な要素を決めます
   - 指示：対象と、いつ・どんな場合に行うかの条件。条件は、満たしたかを読み手が観察できる形で書かれている必要があります。「必要に応じて」のように、満たしたかを観察できない条件は、欠けているものとします。読み手以外が行う動作は、主体も必要です。述語が「〜しない」のような否定の場合は、代わりに取る行動も必要です
   - 完了条件：満たしたかを観察できる状態。観察できるかは、同じディレクトリの`classify-statements.md`の手順で確かめます
   - 変化：変わる前と変わった後
   - 実害：望ましくない結果だと示す表現（「〜てしまう」「〜かねない」「〜を招く」など）
   - 説明：主体と、主体に対応する述語
3. 必要な要素ごとに、その文か、文書のほかの箇所に書かれているかを確かめます。ほかの箇所から導ける場合は、同じディレクトリの`check-information-loss.md`の「導ける」と同じく、導いた語を書きます
4. 書かれていない要素を、欠けている要素として挙げます
5. 欠けている要素は、元の文書にない情報が必要なら補わず、候補と調べる方法を示します。文書のほかの箇所に書かれている場合は、その箇所の語で補う案を示します
