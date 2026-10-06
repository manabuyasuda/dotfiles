<!-- textlint-disable @textlint-ja/ai-writing/no-ai-list-formatting, @textlint-ja/ai-writing/no-ai-hype-expressions, @textlint-ja/ai-writing/ai-tech-writing-guideline, ja-technical-writing/ja-no-redundant-expression, ja-technical-writing/max-ten, ja-technical-writing/no-doubled-joshi, ja-technical-writing/no-doubled-conjunctive-particle-ga, ja-technical-writing/ja-no-successive-word, ja-technical-writing/sentence-length, prh -->

# trace-references.mdのテストの入力

次の文書について、`trace-references.md`の手順で判定してください。

```
# 認証の移行

ADRに記録したとおり、A案で進めます。

外部サービスとはAPI（Application Programming Interface）で連携します。APIの呼び出し回数は1日1000回までです。

ユーザーは、新しい画面からログインします。利用者がログインに失敗した場合は、エラーメッセージを表示します。

## 手順

前述の設定を有効にしてください。
```

次の5つの語ごとに、違反か（はい/いいえ）と、判定の理由を書いてください。

1. 「ADR」
2. 「A案」
3. 2回目に出てくる「API」
4. 「ユーザー」と「利用者」
5. 「前述の設定」
