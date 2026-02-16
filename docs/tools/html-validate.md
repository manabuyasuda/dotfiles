# html-validate

HTML のオフラインバリデーションツール。W3C 仕様に基づく構文チェックに加え、アクセシビリティやベストプラクティスのルールも提供する。

## インストール

```bash
npm install -g html-validate
```

`nodenv/default-packages` で自動インストールされる。

## 基本的な使い方

```bash
# HTML ファイルをバリデーション
html-validate index.html

# glob パターンで複数ファイルをバリデーション
html-validate "src/**/*.html"

# 設定ファイルを初期化
html-validate --init

# 特定のプリセットを使用
html-validate --preset html-validate:recommended index.html

# stdin からの入力
cat index.html | html-validate --stdin
```

## ユースケース

### CI で HTML の品質を担保する

```bash
html-validate "dist/**/*.html"
```

ビルド成果物の HTML をバリデーションし、不正なマークアップがデプロイされることを防ぐ。

### プロジェクト固有のルールを設定する

`.htmlvalidate.json`:

```json
{
  "extends": ["html-validate:recommended"],
  "rules": {
    "no-inline-style": "error",
    "prefer-native-element": "error"
  }
}
```

```bash
html-validate "src/**/*.html"
```

### テンプレートエンジンの出力を検証する

```bash
curl -s http://localhost:3000 | html-validate --stdin
```

サーバーサイドで生成された HTML の品質をチェックする。

## 参考リンク

- [html-validate 公式サイト](https://html-validate.org)
- [GitHub - html-validate](https://github.com/html-validate/html-validate)
- [npm - html-validate](https://www.npmjs.com/package/html-validate)
