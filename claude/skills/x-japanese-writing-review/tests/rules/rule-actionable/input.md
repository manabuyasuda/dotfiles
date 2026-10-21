# rule-actionableのテスト文書

<!-- case:negative-sentence -->

## コミット先

保護ブランチへ直接pushしません。

保護ブランチは`main`と`release`です。

<!-- case:done-criteria -->

## リリース

### 完了条件

- 一覧画面の表示が十分に速いこと
- `npm run build`が終了コード0で終わること

<!-- case:active-voice -->

## 初回ログイン

ログイン後、パスワードの変更が求められます。

インストーラーを起動してください。必要なパッケージがダウンロードされます。

<!-- case:subject-predicate -->

## pre-commit hook

このhookの役割は、保護ブランチへのコミットを拒否します。

このhookは、拒否したコミットの記録を`hook.log`に書き込みます。

<!-- case:object-and-condition -->

## 運用

問題が起きたら戻します。

保存期間の30日を過ぎたログファイルは、毎日0時に削除します。

<!-- case:test-name -->

## テストケース

- `Label`が`null`を返す
- 編集権限がない利用者には、ボタンを表示しない（`isEditable`が`false`）

<!-- case:harm-expression -->

## キャッシュの削除

キャッシュを削除すると、ログイン中の利用者全員がログアウトします。

設定を変更すると、次回の起動時に読み込まれます。

<!-- case:before-and-after -->

## 変更の効果

この変更で、レビューの効率が改善します。

ビルドの所要時間は、v2.0で12分から3分に減りました。

<!-- case:authority -->

## テストの方針

専門家によると、この手法が有効です。

この手法では、入力値を上限と下限の前後で検証します。

<!-- case:external-source -->

## Node.jsのバージョン

Node.js 18のサポートは2025年4月30日に終了しました。

次の設定で、Node.js 20以上を必須にしています。

```json
{ "engines": { "node": ">=20" } }
```

<!-- case:claim-grounds -->

## 判断

このライブラリを採用すべきです。

ビルドが失敗しています。このPRはマージすべきではありません。

<!-- case:literal-verb -->

## テスト

マージする前にテストを回します。

リリースする前に`npm test`を実行します。

<!-- case:concrete-example -->

## 入力値の検証

入力値は境界値で検証します。

検証に失敗した入力は保存しません。
