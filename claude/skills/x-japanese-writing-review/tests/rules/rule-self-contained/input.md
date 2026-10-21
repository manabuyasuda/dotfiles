# rule-self-containedのテスト文書

<!-- case:in-document-reference -->

## 認証の移行

移行はA案で進めます。

移行後は、ログイン画面でメールアドレスとパスワードを入力します。

<!-- case:abbreviation -->

## 設計の記録

決定の経緯はADRに記録します。

外部サービスとはAPI（Application Programming Interface）で連携します。

<!-- case:katakana -->

## 会議の準備

会議のアジェンダをステークホルダーに共有します。

変更はブランチにコミットします。

<!-- case:proper-name -->

## デプロイ

デプロイにはOrcaを使います。

ソースコードはGitで管理します。

<!-- case:consistent-term -->

## ログイン

利用者は、メールアドレスとパスワードでログインします。

サインインに失敗した場合は、エラーメッセージを表示します。

<!-- case:one-meaning-per-word -->

## 設定の変更

変更を`main`に反映します。設定を反映するには、サービスを再起動します。

ログは`/var/log/app`に出力されます。
