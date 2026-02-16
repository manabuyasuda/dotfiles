# wallace-cli

CSS ファイルの統計情報を分析するツール。ファイルサイズ、セレクタ数、宣言数、メディアクエリ数などの指標を一覧表示する。

## インストール

```bash
npm install -g wallace-cli
```

`nodenv/default-packages` で自動インストールされる。

## 基本的な使い方

```bash
# CSS ファイルを分析
wallace path/to/styles.css

# JSON 形式で出力
wallace path/to/styles.css --json

# stdin からの入力
cat styles.css | wallace

# リモート CSS を分析
curl -s https://example.com/styles.css | wallace
```

## ユースケース

### CSS のサイズと複雑度を把握する

```bash
wallace dist/styles.css
```

ファイルサイズ、ルール数、セレクタ数、宣言数、メディアクエリ数などの統計情報を一覧表示し、CSS の肥大化を検知する。

### リファクタリング前後の CSS を比較する

```bash
wallace old-styles.css --json > before.json
wallace new-styles.css --json > after.json
```

JSON 出力を利用してリファクタリング前後の統計情報を比較し、改善効果を定量的に評価する。

### CI で CSS の肥大化を監視する

```bash
wallace dist/styles.css --json | jq '.filesize'
```

ビルド後の CSS サイズを CI で記録し、閾値を超えた場合にアラートを出す。

## 参考リンク

- [GitHub - wallace-cli](https://github.com/projectwallace/wallace-cli)
- [npm - wallace-cli](https://www.npmjs.com/package/wallace-cli)
- [Project Wallace（Web 版）](https://www.projectwallace.com)
