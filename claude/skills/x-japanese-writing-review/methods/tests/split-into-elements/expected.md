<!-- textlint-disable @textlint-ja/ai-writing/no-ai-list-formatting, @textlint-ja/ai-writing/no-ai-hype-expressions, @textlint-ja/ai-writing/ai-tech-writing-guideline, ja-technical-writing/ja-no-redundant-expression, ja-technical-writing/max-ten, ja-technical-writing/no-doubled-joshi, ja-technical-writing/no-doubled-conjunctive-particle-ga, ja-technical-writing/ja-no-successive-word, ja-technical-writing/sentence-length, prh -->

# split-into-elements.mdのテストの期待結果

| 番号 | 期待する結果 | 確かめること |
|---|---|---|
| 1 | 述語は「検索する」。条件に「エラーが起きたとき」、手段に「このスクリプト」、対象に「ログ」がある。文の働きは「指示」 | 条件と文の働きを書き落とさない |
| 2 | 述語は「失敗として扱う」。「失敗する」だけにしていない。条件に「60秒を過ぎる」、対象に「検索」がある | 態や文末を取り除いても、動詞「扱う」を残す |
| 3 | 述語が「読み込む」と「起動する」の2つ。関係は「時間順」 | 述語を分け、関係を決める |
| 4 | 述語が「追加する」と「再発する」の2つ。関係を「因果」と決めていない | 文から決められない関係を、決めつけない |
| 5 | 手段に「キャッシュを使う」、対象に「表示時間」、結果に「0.5秒以内」がある | 手段と結果を分ける |

## 合格条件

2回とも、5文すべてが「期待する結果」を満たすこと。

## 変更の記録

- 2026-10-06：3番の入力を「読み込んで、」から「読み込んでから、」に変えました。て形だけでは時間順とも並列とも読め、期待する結果が人によって分かれる入力だったためです。て形の関係を判定するのは`list-interpretations.md`の役割です
- 2026-10-06：5番が2回のうち1回失敗した原因は、「0.5秒以内に」を述語に含めるか結果に書くかを手順が決めていなかったことでした。手順の2に「『AをBにする』『AがBになる』のBは、述語に含めず結果に書きます」を足しました。期待する結果は変えていません
