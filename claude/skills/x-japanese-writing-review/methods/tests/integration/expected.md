<!-- textlint-disable @textlint-ja/ai-writing/no-ai-list-formatting, @textlint-ja/ai-writing/no-ai-hype-expressions, @textlint-ja/ai-writing/ai-tech-writing-guideline, ja-technical-writing/ja-no-redundant-expression, ja-technical-writing/max-ten, ja-technical-writing/no-doubled-joshi, ja-technical-writing/no-doubled-conjunctive-particle-ga, ja-technical-writing/ja-no-successive-word, ja-technical-writing/sentence-length, prh -->

# 統合テストの期待結果

SKILL.mdの手順で入力の写しを3周校正させます。サブエージェントへの指示は、SKILL.mdの文言をそのまま使わせます。

- `../check-information-loss/integration-input.md`：期待は`../check-information-loss/expected.md`の「統合テスト」に書いています
- `input-actionable.md`：次をすべて満たすことを期待します

1. 「ADR」に正式名称が添えられる。または、正式名称が必要だと報告される
2. 「慎重に行うことが重要です」が、そのまま残らない。削除されるか、具体的な事実が必要だと報告される
3. 「メモリ不足でサーバーが停止しました」が、事実（停止した）と推測（原因はメモリ不足）に分けられるか、推測だとわかる語で書かれる。または、原因を確かめた方法が文書にないので推測だと報告される
4. 「問題が起きたら戻してください」について、対象と条件が欠けていると報告される
5. 「十分に」について、観察できる基準が欠けていると報告される
6. 元の文書にない数値・コマンド・手順を、本文に補って書き換えない。候補として報告するのはよい
7. `rule-concise.md`・`rule-unambiguous.md`・`rule-actionable.md`・`rule-self-contained.md`を担当するサブエージェントが、毎周、各ファイルの「判定に使うメソッド」の表にあるメソッドを1つ以上読む（実行記録で確かめる）

## 合格条件

2つの入力とも、2回の校正でそれぞれの期待をすべて満たすこと。

## 変更の記録

- 2026-10-06：3番目の期待に「原因を確かめた方法が文書にないので推測だと報告される」を足しました。1回目の校正で、書き手がログで原因を確かめたかが文書からわからないため、「考えられます」を足す案と確かめた方法を書く案の両方を候補として報告し、本文は書き換えずに保留していました。どちらが正しいかは元の文書にない情報で決まるので、保留して報告することもSKILL.mdの手順に合っているためです
