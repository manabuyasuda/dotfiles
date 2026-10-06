<!-- textlint-disable @textlint-ja/ai-writing/no-ai-list-formatting, @textlint-ja/ai-writing/no-ai-hype-expressions, @textlint-ja/ai-writing/ai-tech-writing-guideline, ja-technical-writing/ja-no-redundant-expression, ja-technical-writing/max-ten, ja-technical-writing/no-doubled-joshi, ja-technical-writing/no-doubled-conjunctive-particle-ga, ja-technical-writing/ja-no-successive-word, ja-technical-writing/sentence-length, prh -->

# 読んでいる箇所だけで理解できるようにするルール

読み手が同じ文書内の別の箇所を開く必要が生じるかどうかで判定します。

次の表のルールに当てはまるかは、表のメソッドを読み、その手順で判定します。表にないルールは、記号や語の形で判定します。

| ルール | 使うメソッド |
|---|---|
| 文書内の別の箇所を参照させる表現は、指している内容をその場に書きます | `methods/trace-references.md` |
| 略語には初出時に正式名称を併記します | `methods/trace-references.md` |
| 固有の名前には初出時に、何を指すかを1文で添えます | `methods/trace-references.md` |
| 同一の対象には同一の用語を使い、文書内で表記を統一します | `methods/trace-references.md` |

## 文書内の別の箇所を参照させる表現は、指している内容をその場に書きます

読み手は参照先を探して読むことになってしまいます。読んでいた箇所に戻ったあとは、直前の内容を思い出し直すことになってしまいます。

1度しか使わない表現は、指している内容に置き換えます。繰り返し使うラベルは、初出時に括弧書きで指している内容を1文で添えます。

- 誤：「A案で進めます」
- 正：「hookで拒否する案で進めます」
- 誤：「A案を採用します」
- 正：「A案（hookで拒否する案）を採用します」

## 略語には初出時に正式名称を併記します

読み手がその略語を知らないと、意味を調べることになってしまいます。略語を知っている読み手も、何の略かを思い出してから読み進めることになってしまいます。

その文書の想定読者が説明なしで理解できる略語は、そのまま使います。想定読者が文書に書かれていない場合は、文書の内容から判断します。

- 誤：「ADRに記録します」
- 正：「ADR（Architecture Decision Record、アーキテクチャ決定記録）に記録します」

## 固有の名前には初出時に、何を指すかを1文で添えます

読み手がその名前を知らないと、何を指すかを調べることになってしまいます。

## 同一の対象には同一の用語を使い、文書内で表記を統一します

表記が揺れると、読み手は2つの語が同じ対象を指すのか別の対象を指すのかを考え、前の記述を読み返すことになってしまいます。

「ログイン」と「サインイン」、「ユーザー」と「利用者」のように、同じ対象へ複数の語を割り当てている箇所は、どちらか一方に統一します。
