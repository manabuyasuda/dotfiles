<!-- textlint-disable @textlint-ja/ai-writing/no-ai-list-formatting, @textlint-ja/ai-writing/no-ai-hype-expressions, @textlint-ja/ai-writing/ai-tech-writing-guideline, ja-technical-writing/ja-no-redundant-expression, ja-technical-writing/max-ten, ja-technical-writing/no-doubled-joshi, ja-technical-writing/no-doubled-conjunctive-particle-ga, ja-technical-writing/ja-no-successive-word, ja-technical-writing/sentence-length, prh -->

# trace-references.mdのテストの期待結果

| 番号 | 違反か | 確かめること |
|---|---|---|
| 1 | はい | 初出に正式名称も説明もない略語を違反にする |
| 2 | はい | 指している内容が文書のどこにも書かれていないラベルを違反にする |
| 3 | いいえ | 初出で正式名称を添えた略語の、2回目以降を違反にしない |
| 4 | はい | 同じ対象（ログインする人）を別の語で指している箇所を違反にする |
| 5 | はい | 指している内容がその語より前にない指示語を違反にする |

## 合格条件

2回とも、5つすべてが「違反か」の列と一致すること。
