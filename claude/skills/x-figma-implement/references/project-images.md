# 画像の準備

画像のフォーマット選択・解像度バリエーション・Image方式の判定手順をまとめます。対象はReact / Next.jsプロジェクトのみです。

`references/project-instructions.md`の「画像の扱い」「画像の保存先・ファイル名規則」見出しに記載があれば、それを最優先します。記載がなければ以下の手順で自律判断します。

## Step 1: フォーマットを決める

リポジトリ内の既存画像を集計して、優先フォーマットを判定します。固定でWebPに決め打たず、既存方針に合わせます。

```bash
find . -type f \( -name "*.avif" -o -name "*.webp" -o -name "*.jpg" -o -name "*.jpeg" \) \
  -not -path "./node_modules/*" -not -path "*/.next/*" -not -path "*/dist/*" -not -path "*/build/*" \
  | awk -F. '{print tolower($NF)}' | sort | uniq -c | sort -rn
```

| 集計結果 | 優先フォーマット |
|---|---|
| AVIFが他フォーマットより多い | AVIF |
| それ以外 | WebP（デフォルト） |
| ベクター・アイコン | SVG（`references/project-icons.md`を参照） |

## Step 2: Image方式を判定する（2段階）

`next/image`を使うか、共通Imageコンポーネントを使うかを決めます。Next.jsプロジェクトであっても`next/image`を使っていないケースがあるため、2段階で確認します。

### Step 2-1: next.configの存在を確認する

```bash
ls next.config.{ts,js,mjs,cjs} 2>/dev/null
```

| 結果 | 次のステップ |
|---|---|
| 存在する | Step 2-2へ |
| 存在しない | Step 3（共通Imageコンポーネント方針）へ |

### Step 2-2: next/imageの使用実績を確認する

```bash
grep -rn "from ['\"]next/image['\"]" src app pages 2>/dev/null | head
```

| 結果 | 採用する方式 |
|---|---|
| すでに使われている | `next/image`を使う（Step 2-3へ） |
| 使われていない | Step 3（共通Imageコンポーネント方針）へ |

プロジェクトが`next/image`を意図的に使っていない場合（CDN/画像API側で最適化している等）、無理に`next/image`を導入すると既存方針と衝突します。既存実績に合わせます。

### Step 2-3: next/imageを使う場合

`next.config`の`images.deviceSizes` / `images.imageSizes`を確認し、`sizes`属性をそれに沿って指定します。

```bash
grep -A 20 "images" next.config.* 2>/dev/null
```

`sizes`属性は表示領域の幅をブレークポイント別に書きます。誤った`sizes`はムダな大画像配信に繋がるため、必ず指定します。

```tsx
import Image from 'next/image';

<Image
  src="/images/race-banner.webp"
  alt=""
  width={1010}
  height={670}
  sizes="(max-width: 599px) 100vw, 1010px"
/>
```

## Step 3: 共通Imageコンポーネントを使う場合

`next/image`を使わない場合は、プロジェクト内の共通Imageコンポーネントを探します。

### Step 3-1: 既存の共通Imageコンポーネントを検知する

`w`記述子・`x`記述子の生成や解像度バリエーションを扱う既存コンポーネントがある場合、それを使います。

変数名・コンポーネント名はプロジェクトによって異なります。以下のgrep例はあくまで代表例です。`DEVICE_PIXEL_RATIOS`が`DPR_LIST`や`pixelRatios`になっていたり、コンポーネント名が`Image`ではなく`Img` / `OptimizedImage` / `ResponsiveImage` / `MicroCmsImage`のようになっていることがあります。

```bash
# 解像度バリエーション定義の検知（変数名のバリエーション）
grep -rn -E "SRCSET_SIZES|srcsetSizes|imageSizes|deviceSizes|widthList|sizeList|breakpointSizes" \
  src --include="*.ts" --include="*.tsx" 2>/dev/null

# DPR定義の検知（変数名のバリエーション）
grep -rn -E "DEVICE_PIXEL_RATIOS|devicePixelRatio|DPR_LIST|pixelRatios|dprList" \
  src --include="*.ts" --include="*.tsx" 2>/dev/null

# w記述子/x記述子生成関数の検知
grep -rn -E "srcSet|srcset|generateSrcSet|buildSrcSet|createSrcSet" \
  src --include="*.ts" --include="*.tsx" 2>/dev/null

# 共通Imageコンポーネント候補（ファイル名のバリエーション）
find src \( -name "Image.tsx" -o -name "Img.tsx" -o -name "OptimizedImage.tsx" \
  -o -name "ResponsiveImage.tsx" -o -name "*Image.tsx" \) 2>/dev/null

# import元の検知（srcからの相対 / エイリアスのバリエーション）
grep -rn -E "from ['\"]@/(components|shared|ui)/[^'\"]*[Ii]mage['\"]" \
  src --include="*.tsx" 2>/dev/null
```

検知されたら、そのコンポーネントの`Props`を読み、`src` / `width` / `height` / `sizes` / `srcSetType`相当のプロパティの使い分けを把握します。Props名もプロジェクト固有なので、コンポーネント本体の型定義を必ず読みます。

### Step 3-2: 既存コンポーネントがない場合の設計指針

新規に共通Imageコンポーネントを設計するときの観点です。

#### 解像度バリエーションの考え方

| 種別 | 概要 | 例 |
|---|---|---|
| w記述子 | 表示幅に応じて複数解像度の画像を`srcSet`に並べる。`sizes`属性で表示幅を伝える | `srcSet="img-256.webp 256w, img-640.webp 640w, img-1010.webp 1010w" sizes="(max-width: 599px) 100vw, 1010px"` |
| x記述子 | デバイスピクセル比に応じて等倍 / 2倍 / 3倍を切り替える | `srcSet="img.webp 1x, img@2x.webp 2x"` |

| 種別 | sizes | 用途 | 生成サイズ |
|---|---|---|---|
| w記述子 | 必須 | ヒーロー画像・記事本文画像など、ブレークポイントで表示幅が大きく変わる画像 | `srcSet`配列のうち`width × max(DPR)`以下のもの |
| x記述子 | 不要 | アバター・ロゴなど、表示サイズがほぼ固定の画像 | `width × DPR`の組み合わせ（1x, 2x） |

#### 必要な定数とAPI

| 観点 | 設計指針 |
|---|---|
| 解像度バリエーション配列 | 例: `[16, 32, 48, 64, 96, 128, 256, 384, 640, 750, 828, 1010]`。Next.jsの`imageSizes` + `deviceSizes`相当の幅セット。プロジェクトの主要ブレークポイントに合わせて調整する |
| DPR配列 | 例: `[1, 2]`。3xまで対応するかはプロジェクトの方針による |
| 出力方式の切替 | `srcSetType`のようなプロパティで`'w'` / `'x'`を切り替える。デフォルトは`'w'` |
| アスペクト比 | `width` / `height`の比率を維持して各解像度の高さを算出する |
| 画像API有無 | microCMS / imgix / Cloudinary等のAPIがあればクエリパラメーター（`?w=...&h=...&q=...&fm=...&dpr=...`）で動的生成、なければビルド時に各サイズを書き出す |
| 必須Props | `src` / `alt` / `width` / `height` |
| デフォルト品質 | 80〜90程度。プロジェクトの既存方針に合わせて調整する |

#### 実装パターンの参考形

w記述子方式の場合、コンポーネント内部では以下のような処理を行います。

1. `SRCSET_SIZES`配列のうち、`width × max(DPR)`以下のサイズを抽出する
2. 各サイズについて、アスペクト比を維持した高さを計算する
3. 画像APIまたは静的画像のパスからURLを組み立てる
4. `URL サイズw`形式の文字列をカンマ区切りで結合し`srcSet`に渡す
5. `sizes`は受け取った値（未指定なら`100vw`）を渡す

x記述子方式の場合は、`DEVICE_PIXEL_RATIOS`の各値について`?dpr=N`のようなクエリパラメーターを付けたURLを`"URL Nx"`形式で並べます。

## Step 4: Art direction（PC/SP別画像）

PC用とSP用で別の画像（クロップ・縦横比が異なる）を出し分ける場合は`<picture>`を使います。

```tsx
<picture>
  <source media="(min-width: 768px)" srcSet="/images/banner-pc.webp" />
  <img src="/images/banner-sp.webp" alt="" width={375} height={500} />
</picture>
```

レスポンシブ画像（同じ画像の異なる解像度）とart direction（異なる画像）は別概念です。前者は`srcSet` + `sizes`、後者は`<picture>` + `<source media="...">`を使います。両方を組み合わせることもできます。

## Step 5: 画像ファイルの保存と命名

| 項目 | ルール |
|---|---|
| 保存先 | プロジェクトの既存配置に合わせる（`src/assets/images/` / `public/images/`等） |
| ファイル名 | Figmaのノード名をkebab-caseに変換 |
| 拡張子 | Step 1で決めた優先フォーマット |

| Figmaノード名 | ファイル名 |
|---|---|
| `Race Banner` | `race-banner.webp`（または`.avif`） |
| `hero/main-visual` | `hero-main-visual.webp` |

保存先は事前に確認します。

```bash
find . -type d \( -name "images" -o -name "assets" \) -not -path "./node_modules/*" 2>/dev/null | head
```

## Step 6: ユーザーへの提案と承諾を得る

画像の準備の着手前に、Step 1〜5の判断結果をユーザーへ提案して承諾を得てください。フォーマット・コンポーネント・保存先の判断を誤ると後戻りが大きくなります。

### 承諾を省略できる条件（escape hatch）

`references/project-instructions.md`の以下の見出しがすべて埋まっていて、判断がそれに沿っている場合は、承諾フェーズを省略して合意内容の提示のみで実装に進めます。

- 「画像の扱い」（フォーマット優先順位・採用するImage方式・解像度配列など）
- 「画像の保存先・ファイル名規則」

1項目でも空欄ならescape hatchは使えず、通常の承諾フェーズに進みます。

### 進め方

質問・確認のルールは`references/project-confirmation.md`にしたがってください。

このStepでの抽象→具体の絞り込み順は以下です。

- 抽象: フォーマット・Image方式（next/image / 既存共通 / 新規）
- 具体: 解像度配列・記述子方式（w / x）・保存先・命名・art directionの要否

### 提案で必ず触れる項目

| 項目 | 内容 |
|---|---|
| 採用フォーマット | AVIF / WebP / SVG、判断根拠（既存集計結果） |
| Image方式 | `next/image` / 既存共通Imageコンポーネント名 / 新規作成 |
| 共通コンポーネント新規作成の場合 | 配置場所・採用する記述子方式（`w` / `x`）・解像度配列の値 |
| 解像度バリエーション | `w`記述子の場合の`sizes`値、`x`記述子の場合の対応DPR |
| Art direction | PC/SP別画像が必要かどうか |
| 保存先 | 画像ファイルの配置パス |
| ファイル名 | Figmaノード名 → kebab-caseの対応 |

質問文の例は以下です。

| 確認したい分岐 | 質問文（はい/いいえで答えられる肯定文） |
|---|---|
| フォーマット | 「画像フォーマットはWebPで揃えますか？」（はい=WebP / いいえ=AVIFや他で深掘り） |
| Image方式 | 「既存の`src/components/ui/Image/Image.tsx`を使いますか？」（はい=既存流用 / いいえ=`next/image`または新規） |
| 記述子方式 | 「ブレークポイントで表示幅が大きく変わるため`w`記述子を使いますか？」（はい=`w` / いいえ=`x`） |
| Art direction | 「PCとSPで別画像を出し分けますか？」（はい=`<picture>` / いいえ=単一画像） |

承諾を得てから画像の書き出し・コンポーネント実装に進みます。
