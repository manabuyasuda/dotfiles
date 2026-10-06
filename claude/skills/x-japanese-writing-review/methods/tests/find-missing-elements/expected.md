<!-- textlint-disable @textlint-ja/ai-writing/no-ai-list-formatting, @textlint-ja/ai-writing/no-ai-hype-expressions, @textlint-ja/ai-writing/ai-tech-writing-guideline, ja-technical-writing/ja-no-redundant-expression, ja-technical-writing/max-ten, ja-technical-writing/no-doubled-joshi, ja-technical-writing/no-doubled-conjunctive-particle-ga, ja-technical-writing/ja-no-successive-word, ja-technical-writing/sentence-length, prh -->

# find-missing-elements.mdのテストの期待結果

| 番号 | 期待する欠けている要素 | 確かめること |
|---|---|---|
| 1 | 何を戻すか（対象）と、何を問題とするか（条件） | 指示の対象と条件を確かめる |
| 2 | 代わりに取る行動 | 否定の指示に、代わりの行動を求める |
| 3 | なし | 必要な要素がそろった指示を指摘しない |
| 4 | 連絡する主体 | 読み手以外が行う動作の主体を確かめる |
| 5 | 変わる前と変わった後 | 変化を述べる文に、前後の状態を求める |
| 6 | なし | 必要な要素がそろった指示を指摘しない |
| 7 | 主体「目的は」に対応する述語（主語と述語が対応していない） | 説明の文で、主語と述語の対応を確かめる |
| 8 | 望ましくない結果だと示す表現 | 実害の文に、否定的な評価の表現を求める |

## 合格条件

2回とも、8文すべてが「期待する欠けている要素」と一致すること。欠けている要素を挙げる言い回しは問わない。

## 変更の記録

- 2026-10-06：1番が2回とも失敗しました。「問題が起きたら」が書かれているので、条件は欠けていないと判定していました。手順が条件の有無だけを確かめ、満たしたかを観察できるかを確かめていなかったためです。`rule-actionable.md`の例も、「問題が起きたら」を観察できる条件に直すことを求めています。手順の2に、観察できない条件は欠けているとすることを足しました。期待する結果は変えていません
