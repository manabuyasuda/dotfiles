# ImageMagick

画像の変換・編集・生成を行う CLI ツール。リサイズ・フォーマット変換・クロップ・テキスト合成・一括処理など多様な画像操作をスクリプトから実行できる。

## インストール

```bash
brew install imagemagick
```

## 基本的な使い方

```bash
# フォーマット変換
magick input.png output.webp

# リサイズ（幅を指定、高さはアスペクト比を保持）
magick input.jpg -resize 800x output.jpg

# リサイズ（幅・高さを指定、アスペクト比を保持して収まるサイズに）
magick input.jpg -resize 800x600 output.jpg

# 品質を指定して保存（JPEG）
magick input.jpg -quality 85 output.jpg

# 画像情報を表示
magick identify input.png

# 複数ファイルの情報を一覧表示
magick identify *.jpg
```

## 主要オプション

| オプション | 説明 |
|---|---|
| `-resize <geometry>` | 画像をリサイズする（例: `800x600`, `50%`, `800x`） |
| `-crop <geometry>` | 画像をクロップする（例: `200x200+10+10`） |
| `-quality <0-100>` | JPEG/WebP の品質を指定する |
| `-strip` | メタデータ（Exif等）を削除する |
| `-gravity <direction>` | 基準位置を指定する（例: `Center`, `NorthWest`） |
| `-extent <geometry>` | キャンバスサイズを指定する（余白追加に使う） |
| `-background <color>` | 背景色を指定する（例: `white`, `transparent`） |
| `-rotate <degrees>` | 回転する |
| `-flip` / `-flop` | 上下 / 左右に反転する |

## ユースケース

### 一括リサイズ

```bash
# カレントディレクトリの全 JPG を幅 800px にリサイズして別ディレクトリに保存
mkdir -p resized
magick mogrify -path resized -resize 800x *.jpg
```

### Web向けに最適化する

```bash
# メタデータ削除 + 品質調整
magick input.jpg -strip -quality 85 output.jpg

# PNG を WebP に変換
magick input.png -quality 80 output.webp
```

### 正方形にトリミング（中央基準）

```bash
magick input.jpg -gravity Center -resize 400x400^ -extent 400x400 output.jpg
```

### 画像を連結する

```bash
# 横に並べる
magick +append image1.jpg image2.jpg combined.jpg

# 縦に並べる
magick -append image1.jpg image2.jpg combined.jpg
```

## 参考リンク

- [ImageMagick 公式サイト](https://imagemagick.org/)
- [ImageMagick コマンドラインリファレンス](https://imagemagick.org/script/command-line-options.php)
