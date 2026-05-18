# 自己検証サイクル

実装直後にブラウザで確認し、Figmaとの差分を自力で検知・修正します。差分ゼロになるまで実装と検証を繰り返します。

検証は手法を順に総当たりするのではなく、疑う対象に応じて手法を選ぶ流れで進めます。

| 疑う対象 | 使う手法 |
|---|---|
| 全体の見た目 | スクリーンショット目視比較 |
| CSSプロパティの最終値（色・font・余白・border等） | `getComputedStyle` |
| 表示サイズ・座標（width/height/位置） | `getBoundingClientRect` |
| 微細な見た目差（人間が気付かないレベル） | Playwright + pixelmatchでピクセル差分 |
| 見落としやすい状態（ウェブフォント未ロード・画像未ロード等） | 該当API（`document.fonts` / `naturalWidth`等）で個別確認 |
| 構造の妥当性（見出し・ボタン・ランドマーク階層） | `browser_snapshot`のaccessibility tree |

`project-instructions.md`の「検証時の注意点」見出しに記載があれば、それを最優先します。

## 1. スクリーンショット目視比較

ブラウザで実装ページを開き、対象コンポーネントをスクリーンショットします。`explore/{page-slug}/figma/screenshots/`のFigmaスクショと並べて比較します。

確認ポイントは以下です。

- 色・透明度・グラデーションの境界
- フォントの太さ・字形
- 余白・配置
- アイコン・画像の表示サイズと位置
- レイヤー重なりがある箇所のオーバーレイ表示

スクリーンショットは作業用一時ディレクトリ（`explore/{page-slug}/implementation/screenshots/`等）に絶対パスで保存してください。

## 2. getComputedStyleで値照合

CSS変数解決・継承・カスケード適用後の最終値を取得します。マッピングファイルのトークン列の値と数値で照合できます。

```js
() => {
  const el = document.querySelector('[data-testid="target-component"]');
  if (!el) return "element not found";
  const s = getComputedStyle(el);
  return {
    backgroundColor: s.backgroundColor,
    color: s.color,
    fontFamily: s.fontFamily,
    fontSize: s.fontSize,
    fontWeight: s.fontWeight,
    lineHeight: s.lineHeight,
    letterSpacing: s.letterSpacing,
    paddingTop: s.paddingTop, paddingBottom: s.paddingBottom,
    paddingLeft: s.paddingLeft, paddingRight: s.paddingRight,
    marginTop: s.marginTop, marginBottom: s.marginBottom,
    textDecoration: s.textDecoration,
    borderRadius: s.borderRadius,
  };
}
```

CSS Modules / vanilla-extractでクラス名がハッシュ化される環境では、セレクターは部分一致を使います。

```js
const el = document.querySelector('[class*="Button_label"]');
```

### 状態別の検証

`hover` / `focus` / `active`等は、状態を発生させてから取得します。

```js
// focus状態（evaluate内でfocusさせる）
() => {
  const el = document.querySelector('[class*="Button_label"]');
  el.focus();
  return getComputedStyle(el).outlineColor;
}
```

`hover`は`mcp__playwright__browser_hover`でホバーしてから`getComputedStyle`を実行します。

## 3. getBoundingClientRectで表示サイズ・座標を照合

レイアウト計算後の実際の`width` / `height` / `top` / `left`を取得します。figma-extractのマッピングファイルに「親375px中x=16 w=343」のようなレイアウト算出値が記録されていれば、それと直接照合できます。

```js
() => {
  const el = document.querySelector('[class*="ComponentName"]');
  const parent = el?.parentElement;
  if (!el || !parent) return "element not found";
  const e = el.getBoundingClientRect();
  const p = parent.getBoundingClientRect();
  return {
    width: e.width, height: e.height,
    relativeX: e.left - p.left,
    relativeY: e.top - p.top,
    parentWidth: p.width, parentHeight: p.height,
  };
}
```

`getComputedStyle`ではwidth指定値が分かりますが、`box-sizing`や`flex-shrink`で実際の表示サイズが変わるため、両方を確認します。

## 4. Playwright + pixelmatchで画像差分

スクショ同士をピクセル単位で比較し、所定の許容閾値を超える差分を機械検出します。フォント描画の微差で誤検出が出やすいため、許容閾値の運用が必要です。

```js
// browser_evaluateではなく、ローカルでpixelmatchを実行する想定
// npm install pixelmatch pngjs
import pixelmatch from 'pixelmatch';
import { PNG } from 'pngjs';
import fs from 'fs';

const img1 = PNG.sync.read(fs.readFileSync('figma.png'));
const img2 = PNG.sync.read(fs.readFileSync('browser.png'));
const { width, height } = img1;
const diff = new PNG({ width, height });
const numDiffPixels = pixelmatch(img1.data, img2.data, diff.data, width, height, { threshold: 0.1 });

fs.writeFileSync('diff.png', PNG.sync.write(diff));
console.log(`差分ピクセル数: ${numDiffPixels}`);
```

使いどころは以下です。

- 目視ではほぼ同じだが微妙な違和感がある場合
- リファクター前後で見た目が同じか確認したい場合

事前準備は以下です。

- スクショサイズをFigmaと揃える（同じデバイスサイズで撮影）
- フォントの読み込みが終わった状態で撮影（後述「個別状態の確認」参照）

## 5. 個別状態の確認

特定の状態だけ怪しい場合は、該当APIで直接確認します。

### ウェブフォントの読み込み状態

```js
async () => {
  const el = document.querySelector('[class*="ComponentName"]');
  const s = getComputedStyle(el);
  const loaded = await document.fonts.load(`${s.fontWeight} ${s.fontSize} ${s.fontFamily}`);
  return { fontFamily: s.fontFamily, isLoaded: loaded.length > 0 };
}
```

### 画像の読み込み状態

```js
() => {
  const img = document.querySelector('img[src*="banner"]');
  return {
    src: img.src,
    naturalWidth: img.naturalWidth,
    naturalHeight: img.naturalHeight,
    complete: img.complete,
  };
}
```

`naturalWidth: 0`または`complete: false`の場合、画像が読み込めていません。

## 6. accessibility treeで構造妥当性確認

`mcp__playwright__browser_snapshot`でアクセシビリティツリーを取得し、見出し・ボタン・ランドマーク階層を確認します。デザイン比較というよりa11y視点ですが、Figmaで「見出し」として描かれている要素が`<h2>`として実装されているか等、構造の妥当性を機械的に検証できます。

確認ポイントは以下です。

- Figmaで見出しとして描かれているテキストが、Figmaの階層に対応する見出しレベル（h1〜h6）になっているか
- ボタン・リンクが`button` / `link`ロールになっているか
- 装飾アイコンが`aria-hidden`で除外されているか

## 7. レイヤー重なりの注意事項

Figmaでは複数のレイヤーを同一座標に自由に重ねられますが、HTMLでは描画順がDOM順と`z-index`に制約されます。

| Figmaのパターン | HTMLで起きやすい問題 | 正しい実装方針 |
|---|---|---|
| 画像の上にグラデーションオーバーレイ | `background-image`は`<img>`の後ろに描画されるため画像で隠れる | `position: absolute`の擬似要素または子要素でオーバーレイを前面に配置する |
| 半透明レイヤーが複数の子要素をまたぐ | 親の`background`で表現すると対象範囲がずれる | 包む要素の`::before`等で実装範囲を正確に指定する |
| テキストが画像・背景の上に重なる | `z-index`未指定で期待通りに前面に出ない | `position: relative`と`z-index`を明示する |

`getComputedStyle`でプロパティが正しくても見た目が異なる場合は、DOM構造または重ね合わせコンテキストの設計を見直します。

## 8. ユーザーへの完了報告

差分ゼロまで反復した後、実装結果をユーザーへ報告して完了とします。検証だけして報告せずに作業を終えると、ユーザーは「どこまで進んだか」「何が残っているか」を把握できません。

報告で必ず触れる項目は以下です。

| 項目 | 内容 |
|---|---|
| 実装したファイル | 新規作成・編集したコンポーネントのパス一覧 |
| 使用したトークン | マッピングファイルのトークン列のうち、実コードに反映したもの |
| アイコン・画像の追加 | 書き出したSVG・画像ファイルのパス |
| 検証結果 | スクリーンショット比較・`getComputedStyle`・`getBoundingClientRect`・pixelmatch・a11y treeのうち実施した手法と結果 |
| 残った懸念点 | 検証でゼロにできなかった差異・LCP対象画像のような後続対応が必要な点・ユーザーに最終判断を委ねたい点 |
| 次のアクション提案 | 関連ページの実装・テスト追加・Storybook追加など、続けて行うとよい作業（あれば） |

懸念点がない場合は「残った懸念点: なし」と明示します。報告を省略しないことで、ユーザーは安心してレビュー・マージへ進めます。
