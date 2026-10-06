<!-- textlint-disable @textlint-ja/ai-writing/no-ai-list-formatting, @textlint-ja/ai-writing/no-ai-hype-expressions, @textlint-ja/ai-writing/ai-tech-writing-guideline, ja-technical-writing/ja-no-redundant-expression, ja-technical-writing/max-ten, ja-technical-writing/no-doubled-joshi, ja-technical-writing/no-doubled-conjunctive-particle-ga, ja-technical-writing/ja-no-successive-word, ja-technical-writing/sentence-length, prh -->

# classify-statements.mdのテストの期待結果

| 番号 | 期待する結果 | 確かめること |
|---|---|---|
| 1 | 「14時に停止した」は観察できる事実 | 日時と出来事を事実にする |
| 2 | 「原因はメモリ不足」は推測で、推測だとわかる語がない | 断定の形でも、確かめた方法がない原因を推測にする |
| 3 | 「原因はメモリ不足」は推測で、推測だとわかる語がある | 推測だとわかる語を書き出す |
| 4 | 「非常に重要」は評価で、評価の基準がない | 基準のない程度の語を評価にする |
| 5 | 「0.8秒から2.1秒に延びた」は観察できる事実 | 数値を事実にする |
| 6 | 「十分に」は評価で、評価の基準がない | 完了条件の中の評価の語を見つける |
| 7 | 「有効」は文書の外の事実か評価で、出典がない。「専門家」を出典として扱っていない | 誰を指すか特定できない主体を出典にしない |
| 8 | 「終了コード0で終わった」は観察できる事実 | 実行結果を事実にする |

## 合格条件

2回とも、8文すべてが「期待する結果」を満たすこと。
