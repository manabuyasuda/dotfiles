# colorguard

CSS内の類似色を検出するツール。CIEDE2000色差アルゴリズムで視覚的に区別しにくい色の組み合わせを見つけ、カラーパレットの整理を支援する。

## インストール

```bash
npm install -g colorguard
```

`nodenv/default-packages`で自動インストールされる。

## 基本的な使い方

```bash
# CSSファイル内の類似色を検出
colorguard --file styles.css

# 類似度の閾値を指定（デフォルトは3）
colorguard --file styles.css --threshold 5

# stdinからの入力
cat styles.css | colorguard
```

## 主要オプション

| オプション | 説明 |
|---|---|
| `--file <path>` | 解析対象のCSSファイルを指定 |
| `--threshold <N>` | 色差の閾値（デフォルト: 3、0〜100、小さいほど厳密） |
| `--allow-equivalent-notation` | 同一色の異なる表記（`#000`と`black`等）を許可 |
| `--options <file>` | オプションをJSONファイルで指定（`--threshold`を上書き） |

### オプションJSONファイルの設定項目

`--options`で指定するJSONファイルには、CLI単体では指定できない項目も設定できる。

```json
{
  "threshold": 3,
  "allowEquivalentNotation": false,
  "ignore": ["#fff"],
  "whitelist": [["#000000", "#010101"]]
}
```

| 項目 | 説明 |
|---|---|
| `threshold` | 色差の閾値 |
| `allowEquivalentNotation` | 同一色の異なる表記を許可 |
| `ignore` | 完全に無視する色を16進数で指定 |
| `whitelist` | 許可する色ペアの配列（ペアごとに`[色A, 色B]`） |

## ユースケース

### CSSカラーパレットの重複を整理する

```bash
colorguard --file dist/styles.css
```

プロジェクト全体で使われている類似色を検出し、CSSカスタムプロパティやデザイントークンに統合する候補を見つける。

### デザイントークン導入前の調査に使う

```bash
colorguard --file styles.css --threshold 10
```

閾値を広めに設定して、統合可能な色のペアを網羅的に洗い出す。デフォルトの3では検出されない「やや似ている」色も含めて把握できる。

### 同一色の表記揺れを許可する

```bash
colorguard --file styles.css --allow-equivalent-notation
```

`#000`と`#000000`や`black`のように、同じ色の異なる表記を許可する。意図的に複数の表記を使い分けているプロジェクトで誤検知を抑制できる。

### 許容する色ペアを設定して運用する

```json
{
  "threshold": 3,
  "whitelist": [["#f0f0f0", "#efefef"]],
  "ignore": ["#ffffff"]
}
```

```bash
colorguard --file dist/styles.css --options colorguard.json
```

意図的に使い分けている類似色をホワイトリストに登録し、誤検知を避けつつCIで監視する。

### CIでカラーパレットの肥大化を防ぐ

```bash
colorguard --file dist/styles.css --options colorguard.json
```

新しい色が追加された際に類似色がないかCIでチェックし、不必要なカラーバリエーションの増加を防ぐ。違反があるとexit code 1を返す。

## 参考リンク

- [GitHub - colorguard](https://github.com/SlexAxton/css-colorguard)
- [npm - colorguard](https://www.npmjs.com/package/colorguard)
