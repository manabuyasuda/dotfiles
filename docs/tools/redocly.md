# Redocly CLI

OpenAPI ドキュメントの管理・バリデーション・バンドルツール。API 仕様の品質管理やドキュメント生成を支援する。

## インストール

```bash
npm install -g @redocly/cli
```

`nodenv/default-packages` で自動インストールされる。

## 基本的な使い方

```bash
# OpenAPI ファイルをバリデーション
redocly lint openapi.yaml

# 複数ファイルに分割した OpenAPI を1ファイルにバンドル
redocly bundle openapi.yaml -o bundled.yaml

# API ドキュメントをプレビュー
redocly preview-docs openapi.yaml

# 統計情報を表示
redocly stats openapi.yaml

# OpenAPI 3.0 から 3.1 などバージョン変換
redocly bundle openapi.yaml --dereferenced -o output.yaml
```

## ユースケース

### CI で OpenAPI 仕様の品質を検証する

```bash
redocly lint openapi.yaml
```

API 仕様のバリデーションを CI に組み込み、不正な定義やベストプラクティス違反を検出する。

### 分割管理した OpenAPI ファイルをバンドルする

```bash
redocly bundle openapi.yaml -o dist/openapi.yaml
```

`$ref` で分割管理している OpenAPI ファイルを1つにまとめ、API ゲートウェイやクライアント生成ツールに渡す。

### ローカルで API ドキュメントを確認する

```bash
redocly preview-docs openapi.yaml
```

ブラウザで Redoc 形式の API ドキュメントをプレビューし、変更を即座に確認する。

## 参考リンク

- [Redocly 公式サイト](https://redocly.com)
- [GitHub - redocly-cli](https://github.com/Redocly/redocly-cli)
- [npm - @redocly/cli](https://www.npmjs.com/package/@redocly/cli)
