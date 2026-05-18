# プロジェクト固有指示（ユーザー記入欄）

このファイルはプロジェクト固有の判断や設計をユーザーが記述する欄です。記載がある項目は、他のreferenceファイルやエージェントの自律判断より最優先で使われます。記載がない項目はエージェントが他のreferenceや自律判断で処理します。

各見出しの下にプロジェクト固有のルール・参照ドキュメントへのパス・既存コンポーネントの一覧などを書いてください。空欄のままでも構いません。

## アーキテクチャ・設計の参照ドキュメント

Step 1で最初に読むドキュメントを記載します。記載例は`docs/architecture.md`・`docs/frontend/design-system.md`・Notionのリンクなどです。

（記載なし）

## 採用しているアーキテクチャパターン

記載例は以下です。複数組み合わせている場合はその関係も記載します。

- Atomic Design（atoms/molecules/organisms/templates/pages）
- FSD（shared/entities/features/widgets）
- FSD + Atomic Design（shared/uiにAtoms/Molecules）

（記載なし）

## コンポーネント配置・命名規約

記載例は「共通UIは`src/components/ui/`配下・PascalCase」「ページ専用は`app/{route}/_components/`」「Stylesは同じディレクトリに`{Name}.module.css`」などです。

（記載なし）

## 既存共通コンポーネント

流用優先のコンポーネントを列挙します。記載例は「ボタンは`src/components/ui/Button/Button.tsx`、リンクは`src/components/ui/Link/Link.tsx`、見出しは`src/components/ui/Heading/Heading.tsx`」などです。

（記載なし）

## アイコンの実装方法

記載例は「単色アイコンは`src/components/icons/{Name}/index.tsx`にインラインSVGで実装」「多色アイコンは`public/icons/`にSVGを置き`<img>`で参照」「`@svgr/webpack`で`.svg`を直接importする」などです。

（記載なし）

## アイコンの保存先・ファイル名規則

記載例は「保存先は`src/assets/icons/`」「ファイル名はkebab-caseで`chevron-right.svg`」「カテゴリ別にサブディレクトリを切る（`icons/grade/g1.svg`）」などです。

（記載なし）

## 画像の扱い

記載例は以下です。

- フォーマットはAVIF優先
- `next/image`は使わず共通Imageコンポーネント`src/components/ui/Image/Image.tsx`を使う
- `SRCSET_SIZES`は`[16,32,64,128,256,384,640,750,828,1010]`
- 画像APIはmicroCMS

（記載なし）

## 画像の保存先・ファイル名規則

記載例は「保存先は`public/images/`」「ファイル名はkebab-caseでFigmaノード名から変換」「ページごとにサブディレクトリを切る（`images/{page-slug}/banner.webp`）」「拡張子は`.webp`を優先」などです。

（記載なし）

## スタイル実装の規約

記載例は「色トークンは`vars.fg.*`を使う、ハードコードは禁止」「タイポグラフィは`typography['body-sm-bold']`形式」「`@/styles`からtokenをインポート」「CSS Modulesでクラス名はkebab-case」などです。

（記載なし）

## インポートパス・パスエイリアス

記載例は「`@/`は`src/`のエイリアス」「`@/styles`は`src/styles/generated/`を指す」「テストでは`~/`エイリアスを使う」などです。`tsconfig.json`の`paths`設定と対応します。

（記載なし）

## 検証用URL・開発サーバー

Step 5の検証で使うURLを記載します。記載例は「開発サーバーは`npm run dev`で`http://localhost:3000`」「対象ページのURLは`/race/{raceId}`形式」「Storybookは`npm run storybook`で`http://localhost:6006`」などです。

（記載なし）

## 検証時の注意点

記載例は「ヒーロー画像はLCP対象なので`loading="eager"`」「`next/font`でNoto Sans JPを読み込んでいるため、初回ロード時はフォント差異が出る」「dark modeの検証は別ページ（`?theme=dark`）で行う」「ピクセル差分の許容閾値は0.1」などです。

（記載なし）

## その他のプロジェクト固有ルール

上記カテゴリに収まらないが、エージェントが守るべきルールを記載します。

（記載なし）
