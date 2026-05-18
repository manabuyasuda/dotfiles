# アイコンの実装

Figmaから取得したアイコンは色数で実装方法を分けます。

`references/project-instructions.md`の「アイコンの実装方法」「アイコンの保存先・ファイル名規則」見出しに記載があれば、それを最優先します。記載がなければ以下の手順で自律判断します。

## 判定基準

マッピングファイルの`### アイコン`表で記録された`fill色`と、Figma上のレイヤー構成を見て判定します。

| 種別 | 判断基準 | 実装方法 |
|---|---|---|
| 単色アイコン | fill / strokeが1色のみ（マッピングファイルの`fill色`が単一） | JSXにインライン`<svg>`として直書きし、`currentColor`で色を受け取る |
| 多色アイコン | fill / strokeが2色以上 | プロジェクトの既存パターンに合わせる（後述） |

## 単色アイコンの実装

```tsx
<svg width="16" height="16" viewBox="0 0 16 16" fill="none" aria-hidden="true">
  <path d="..." fill="currentColor" />
</svg>
```

- `fill="currentColor"`で親要素の`color`を継承します。マッピングファイルの色トークンは`color`プロパティとして親要素に当てます
- 装飾的なアイコンは`aria-hidden="true"`、意味のあるアイコンは`aria-label`を付けます

サイズはマッピングファイルの`サイズ（w×h）`列の値を`width` / `height`に当てます。

## 多色アイコンの実装

多色アイコンは`currentColor`制御ができないため、プロジェクトの既存パターンに合わせます。

### Step 1: 既存パターンを確認する

```bash
# アイコン用ディレクトリ・コンポーネントを探す
find src -type d \( -name "icons" -o -name "icon" \) 2>/dev/null
find src -type f \( -name "Icon.tsx" -o -name "*Icon.tsx" \) 2>/dev/null | head
grep -rn "import.*\.svg" src --include="*.tsx" 2>/dev/null | head
```

### Step 2: パターン別の実装

| 既存パターン | 実装方法 |
|---|---|
| SVGファイルを直接import | `import IconName from './icon-name.svg';` + `<IconName />`または`<img src={IconName} />` |
| SVGスプライト | `<svg><use href="/icons/sprite.svg#icon-name" /></svg>` |
| アイコンコンポーネント集約 | `<Icon name="icon-name" />`のような既存コンポーネントを使う |
| `<img>`で参照 | `<img src="/icons/icon-name.svg" alt="" />` |

### Step 3: SVGファイルの保存

| 項目 | ルール |
|---|---|
| 保存先 | プロジェクトの既存配置に合わせる（`src/assets/icons/` / `public/icons/`等） |
| ファイル名 | Figmaのコンポーネント名をkebab-caseに変換 |

| Figmaコンポーネント名 | ファイル名 |
|---|---|
| `chevron-right` | `chevron-right.svg` |
| `grade-icon/g1` | `grade-icon-g1.svg` |

## アクセシビリティ

| 用途 | 属性 |
|---|---|
| 装飾的（テキストが隣接している） | `aria-hidden="true"` |
| 意味を持つ（単独使用・ボタン内のみ） | `aria-label="〜"`（または隣接する`<span class="sr-only">`でラベル提供） |

## 共通注意事項

- マッピングファイルに`fill色`が`var(--fg/default)`のようなトークン参照で記録されている場合、単色アイコンとして実装し親要素にそのトークンを`color`で当てます
- アイコンサイズはマッピングファイルの値を使います。Figmaのキャンバス上で見たサイズと異なる場合があるため推測しません

## ユーザーへの提案と承諾を得る

アイコン実装の着手前に、判断結果をユーザーへ提案して承諾を得てください。

### 承諾を省略できる条件（escape hatch）

`references/project-instructions.md`の以下の見出しがすべて埋まっていて、判断がそれに沿っている場合は、承諾フェーズを省略して合意内容の提示のみで実装に進めます。

- 「アイコンの実装方法」
- 「アイコンの保存先・ファイル名規則」

1項目でも空欄ならescape hatchは使えず、通常の承諾フェーズに進みます。

### 進め方

質問・確認のルールは`references/project-confirmation.md`にしたがってください。

このStepでの抽象→具体の絞り込み順は以下です。

- 抽象: 実装方法（インラインSVG / `<img>` / SVGスプライト / アイコンコンポーネント集約）
- 具体: 保存先・命名・アクセシビリティ属性

### 提案で必ず触れる項目

| 項目 | 内容 |
|---|---|
| アイコン種別 | 単色 / 多色の判定結果 |
| 実装方法 | インラインSVG / `<img>` / SVGスプライト / アイコンコンポーネント集約のいずれか |
| 保存先 | SVGファイルの配置パス（多色の場合） |
| ファイル名 | Figmaコンポーネント名 → kebab-caseの対応 |
| アクセシビリティ属性 | `aria-hidden` / `aria-label`のどちらを使うか |

質問文の例は以下です。

| 確認したい分岐 | 質問文（はい/いいえで答えられる肯定文） |
|---|---|
| 実装方法 | 「単色アイコンはインラインSVGで実装しますか？」（はい=インラインSVG / いいえ=他方式へ深掘り） |
| 保存先 | 「多色アイコンは`public/icons/`配下に置きますか？」（はい=その場所 / いいえ=既存パターンへ深掘り） |
| アクセシビリティ | 「このアイコンは装飾用なので`aria-hidden`を付けますか？」（はい=装飾 / いいえ=`aria-label`へ） |

承諾を得てから実装に進みます。
