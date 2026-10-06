<!-- textlint-disable @textlint-ja/ai-writing/no-ai-list-formatting, @textlint-ja/ai-writing/no-ai-hype-expressions, @textlint-ja/ai-writing/ai-tech-writing-guideline, ja-technical-writing/ja-no-redundant-expression, ja-technical-writing/max-ten, ja-technical-writing/no-doubled-joshi, ja-technical-writing/no-doubled-conjunctive-particle-ga, ja-technical-writing/ja-no-successive-word, ja-technical-writing/sentence-length, prh -->

# list-interpretations.mdのテストの入力

各項目の「判定する語句」が、複数の意味に解釈できるかを、`list-interpretations.md`の手順で判定してください。「前後の文」がある項目は、その文も手がかりにします。

1. 前後の文：「設定ファイルとログファイルを確認しました。」
   文：「片方に誤りがありました。」
   判定する語句：「片方」
2. 文：「新しいユーザーの設定画面を作ります。」
   判定する語句：「新しい」
3. 文：「最新版にアップデートしてください。」（文書に版の番号はどこにも書かれていない）
   判定する語句：「最新版」
4. 文：「テストを追加して、不具合が再発しました。」
   判定する語句：「追加して、」
5. 文：「接続数が上限を超えたときは、対応してください。」
   判定する語句：「対応して」
6. 文：「古いサーバーのバックアップを削除します。」
   判定する語句：「古い」
7. 文：「エラーが起きたときは、ログを確認してください。」
   判定する語句：「エラーが起きたとき」
8. 文：「設定ファイルを読み込んで、サーバーを起動します。」
   判定する語句：「読み込んで、」
9. 文：「v2.4にアップデートしてください。」
   判定する語句：「v2.4」
10. 前後の文：「設定ファイルとログファイルを確認しました。」
   文：「設定ファイルに誤りがありました。」
   判定する語句：「設定ファイル」
11. 文：「ログイン画面の背景色を変更します。」
   判定する語句：「ログイン画面の背景色」

12. 前後の文：「各設定ファイルの値を、本番用に書き換えました。」
   文：「設定ファイルを、環境ごとに異なる組にしました。」
   判定する語句：「組にしました」
13. 文：「4人ずつの組に分かれて、レビューを行います。」
   判定する語句：「組」
14. 文：「検索結果は、拠点ごとの組にして表示します。」
   判定する語句：「組」

15. 文：「エラーの記録を、画面ごとの組にして保存します。」
   判定する語句：「組にして」

番号ごとに「違反か（はい/いいえ）」、最後まで残った解釈、判定の理由、修正案（示す場合）を書いてください。
