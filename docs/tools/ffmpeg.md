# ffmpeg

動画・音声の変換・処理を行うマルチメディアフレームワークCLI。エンコード・デコード・トリミング・結合・フィルタリングなど幅広い操作を1コマンドで行える。

## インストール

```bash
brew install ffmpeg
```

## 基本的な使い方

```bash
# 動画を別フォーマットに変換
ffmpeg -i input.mp4 output.webm

# 音声を抽出
ffmpeg -i input.mp4 -vn output.mp3

# 動画をトリミング（30秒から60秒間）
ffmpeg -i input.mp4 -ss 00:00:30 -t 00:01:00 output.mp4

# 解像度を変更
ffmpeg -i input.mp4 -vf scale=1280:720 output.mp4

# 動画情報を表示
ffprobe input.mp4
```

## 主要オプション

| オプション | 説明 |
|---|---|
| `-i <file>` | 入力ファイルを指定する |
| `-ss <time>` | 開始時刻を指定する（例: `00:01:30` または `90`秒） |
| `-t <duration>` | 処理する長さを指定する |
| `-to <time>` | 終了時刻を指定する |
| `-vn` | 映像ストリームを除外する（音声のみ抽出） |
| `-an` | 音声ストリームを除外する（映像のみ） |
| `-vf <filter>` | 映像フィルターを適用する |
| `-crf <0-51>` | 映像品質を指定する（低いほど高品質、推奨: 18-28） |
| `-c:v <codec>` | 映像コーデックを指定する（例: `libx264`, `libvpx-vp9`） |
| `-c:a <codec>` | 音声コーデックを指定する（例: `aac`, `libmp3lame`） |
| `-y` | 出力ファイルが存在する場合に上書きする |

## ユースケース

### Web向けに動画を最適化する

```bash
ffmpeg -i input.mp4 -c:v libx264 -crf 23 -c:a aac -b:a 128k output.mp4
```

### GIFを動画に変換する

```bash
ffmpeg -i animation.gif -movflags faststart -pix_fmt yuv420p output.mp4
```

### 動画から静止画を切り出す

```bash
# 1秒ごとに1枚を切り出す
ffmpeg -i input.mp4 -vf fps=1 frame_%04d.png

# 特定の時刻の1枚を切り出す
ffmpeg -i input.mp4 -ss 00:00:10 -vframes 1 thumbnail.jpg
```

### 複数の動画を結合する

```bash
# ファイルリストを作成
printf "file 'part1.mp4'\nfile 'part2.mp4'" > list.txt
ffmpeg -f concat -safe 0 -i list.txt -c copy output.mp4
```

### 動画のサムネイルを生成する

```bash
ffmpeg -i input.mp4 -ss 00:00:05 -vframes 1 -vf scale=640:-1 thumbnail.jpg
```

## 参考リンク

- [ffmpeg 公式サイト](https://ffmpeg.org/)
- [ffmpeg ドキュメント](https://ffmpeg.org/documentation.html)
