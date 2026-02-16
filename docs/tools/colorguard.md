# colorguard

CSS 内の類似色を検出するツール。視覚的に区別しにくい色の組み合わせを見つけ、カラーパレットの整理を支援する。

## インストール

```bash
npm install -g colorguard
```

`nodenv/default-packages` で自動インストールされる。

## 基本的な使い方

```bash
# CSS ファイル内の類似色を検出
colorguard --file styles.css

# 類似度の閾値を指定（デフォルトは 3）
colorguard --file styles.css --threshold 5

# stdin からの入力
cat styles.css | colorguard

# 許可する色のペアを指定
colorguard --file styles.css --whitelist "#fff,#fefefe"
```

## ユースケース

### CSS カラーパレットの重複を整理する

```bash
colorguard --file dist/styles.css
```

プロジェクト全体で使われている類似色を検出し、CSS カスタムプロパティやデザイントークンに統合する候補を見つける。

### デザイントークン導入前の調査に使う

```bash
colorguard --file styles.css --threshold 10
```

閾値を広めに設定して、統合可能な色のペアを網羅的に洗い出す。

### CI でカラーパレットの肥大化を防ぐ

```bash
colorguard --file dist/styles.css
```

新しい色が追加された際に類似色がないか CI でチェックし、不必要なカラーバリエーションの増加を防ぐ。

## 参考リンク

- [GitHub - colorguard](https://github.com/SlexAxton/css-colorguard)
- [npm - colorguard](https://www.npmjs.com/package/colorguard)
