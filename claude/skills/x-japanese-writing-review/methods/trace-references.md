<!-- textlint-disable @textlint-ja/ai-writing/no-ai-list-formatting, @textlint-ja/ai-writing/no-ai-hype-expressions, @textlint-ja/ai-writing/ai-tech-writing-guideline, ja-technical-writing/ja-no-redundant-expression, ja-technical-writing/max-ten, ja-technical-writing/no-doubled-joshi, ja-technical-writing/no-doubled-conjunctive-particle-ga, ja-technical-writing/ja-no-successive-word, ja-technical-writing/sentence-length, prh -->

# 語が、文書内のどこを指しているかを確かめる手順

読み手が、文書の別の箇所を探しに行く必要が生じるかを判定します。

## 手順

1. 判定する語を挙げます。対象は、指示語（「この」「前述の」など）、ラベル（「A案」など）、略語、固有の名前、同じ対象を指していそうな別の語です
2. 語の種類ごとに、次のことを確かめます
   - 指示語とラベル：指している内容が、同じ段落の、その語より前に書かれているか。書かれていない場合は、指している内容が文書のどこにあるか、どこにもないかを書き出します
   - 略語と固有の名前：文書内での初出か。初出の場合、正式名称か、何を指すかの説明が添えられているか。説明がない場合は、文書に書かれた想定読者か、文書の内容から、説明なしで理解できるかを書き出します
   - 同じ対象を指していそうな別の語：2つの語について、同じディレクトリの`split-into-elements.md`の手順で、述語と要素を比べます。同じ主体や対象として使われていれば、同じ対象を指す別の語と判定します
3. 次のどれかに当たる語を、違反として挙げます
   - 指している内容が、同じ段落のその語より前にない指示語とラベル
   - 初出に説明がなく、想定読者が説明なしで理解できない略語と固有の名前
   - 同じ対象を、別の語で指している箇所
