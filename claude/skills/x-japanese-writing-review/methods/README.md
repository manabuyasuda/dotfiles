<!-- textlint-disable @textlint-ja/ai-writing/no-ai-list-formatting, @textlint-ja/ai-writing/no-ai-hype-expressions, @textlint-ja/ai-writing/ai-tech-writing-guideline, ja-technical-writing/ja-no-redundant-expression, ja-technical-writing/max-ten, ja-technical-writing/no-doubled-joshi, ja-technical-writing/no-doubled-conjunctive-particle-ga, ja-technical-writing/ja-no-successive-word, ja-technical-writing/sentence-length, prh -->

# 判定に使うメソッド

ルールに当てはまるかを判定するときに、複数のルールで使う手順です。ルールファイルとSKILL.mdは、必要なメソッドを参照し、組み合わせて判定します。印象で判定すると、同じ文書でも判定する回によって結果が分かれてしまうためです。

## メソッドの一覧

| メソッド | 判定すること | 使う場所 |
|---|---|---|
| `split-into-elements.md` | 文を述語・要素・文の働きに分ける | ほかのメソッドすべて、`rule-concise.md`、`rule-unambiguous.md` |
| `check-information-loss.md` | 削除や書き換えで、読み手が文書から得られる情報が減らないか | `rule-concise.md`、`find-missing-elements.md`、SKILL.mdのEditする前の確認 |
| `list-interpretations.md` | 語句や文が、複数の意味に解釈できるか | `rule-unambiguous.md`、`rule-actionable.md` |
| `classify-statements.md` | 文の内容を、観察できる事実・推測・評価に分ける | `rule-concise.md`、`rule-unambiguous.md`、`rule-actionable.md`、`find-missing-elements.md` |
| `find-missing-elements.md` | 読み手が行動や採否を決めるのに必要な要素が欠けていないか | `rule-actionable.md` |
| `trace-references.md` | 語が、文書内のどこを指しているか | `rule-self-contained.md` |

どのルールがどのメソッドを使うかは、各ルールファイルの冒頭の表に書いています。`rule-formatting.md`は記号や記法の形だけで判定するので、メソッドを使いません。

メソッドを追加するときは、1つのルールでしか使わない手順にはしません。複数のルールで使える粒度にまとめ、ルールの側で組み合わせます。

## テスト

メソッドごとに`tests/<メソッド名>/`を置きます。複数のメソッドとルールを組み合わせた結果は、`tests/integration/`の統合テストで確かめます。

- `cases.md`：テストの入力です。テストを実行するエージェントに渡します
- `expected.md`：期待する結果と合格条件です。テストを実行するエージェントには渡しません。期待する結果を読んだエージェントは、手順ではなく期待する結果に合わせて判定してしまうためです

テストは次の手順で実行します。

1. メソッドのファイルと`cases.md`だけを読むよう指示したサブエージェントを、2つ別々に起動します。メソッドがほかのメソッドを参照している場合は、参照先のファイルも読ませます
2. 2つの結果を`expected.md`と照らし合わせます
3. `expected.md`の合格条件を2回とも満たした場合だけ、合格とします

ケースは次の方針で作ります。

- メソッドが判定することだけを確かめます。ルールの例どおりに判定できるかは、統合テストで確かめます
- 期待する結果は、テストを実行する前に決めます。人によって期待が分かれる入力は、ケースに使いません
- 実際に起きた失敗は、再現するケースとして残します
- テストの結果を見てから、ケースや期待する結果を変えた場合は、変えた理由を`expected.md`の「変更の記録」に書きます

## コミットしてよい条件

メソッドまたはメソッドを参照するファイルを変更したコミットは、次の2つを満たしたときだけ作ります。

- 変更したメソッドと、そのメソッドを参照しているメソッドのテストが、すべて合格している
- メソッドの不具合を直すためにケースを追加した場合は、直す前の版でそのケースが失敗することを確かめている。直す前から合格するケースでは、直したことを確かめられないためです
