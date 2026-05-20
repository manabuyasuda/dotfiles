# markup-rules

要素を「見た目」ではなく「役割」から判断するためのマークアップルール集の索引です。詳細は `rules/markup/` 配下の各ファイルを参照してください。

## 共通原則

- 「これは何ができる要素か」を先に確定してから実装します
- 役割がデザインカンプから読み取れない場合は推測せず、`AskUserQuestion`で1つずつ確認します
- ネイティブHTMLで実現できる役割は、ARIAやJavaScriptで代替しません

## Figmaデータから検知できるルール

Figmaデータに以下の特徴があれば、対応するルールを適用します。

| Figmaで見える特徴 | 適用するルール | 確認事項 |
|---|---|---|
| クリックされそうな要素（ボタン状・リンク状） | `semantic-link-href`・`semantic-button-action` | クリック後の挙動をユーザーに確認 |
| 同じ形のカード・項目がAuto Layoutで繰り返されている | `semantic-list-items` | リスト構造として実装 |
| Heading系のテキストスタイルが付いたテキスト | `semantic-heading-order` | 階層と順番を確認 |
| ヘッダー・フッター・サイドバー・メインコンテンツ領域 | `semantic-main-landmark`・`semantic-nav-landmark` | ランドマーク要素で囲む |
| タブ・アコーディオン・モーダル等の動的UI | `a11y-aria-patterns` | APGに準拠した属性とキーボード操作を実装 |
| 画像（`<img>`で実装する予定の要素） | `a11y-image-alt`・`perf-image-srcset` | altと解像度最適化を両方検討 |

## Figmaに見えなくても常に適用するルール

| ルール | 内容 |
|---|---|
| `semantic-no-section` | 実装で`<section>`を使わない |
| `a11y-focus-indicator` | フォーカス可能要素に可視フォーカスを保つ |

## 適用順序

次の順番でチェックします。

1. ページ全体（`semantic-main-landmark`・`semantic-heading-order`・`semantic-nav-landmark`）
2. 要素ごと（`semantic-link-href`・`semantic-button-action`・`a11y-focus-indicator`・`a11y-aria-patterns`）
3. 構造（`semantic-list-items`）
4. 画像（`a11y-image-alt`・`perf-image-srcset`）
5. 実装全般（`semantic-no-section`）
6. 判定不能は`AskUserQuestion`で1つずつユーザー確認

なお、`semantic-link-href`と`semantic-button-action`は排他です（同じ要素にはどちらか一方を適用）。他のルールは条件に該当すれば重ねて適用します。

## ファイル構成

```
rules/markup/
├── _sections.md          # セクション定義
├── _template.md          # 新規ルール作成用テンプレート
├── semantic-link-href.md
├── semantic-button-action.md
├── semantic-list-items.md
├── semantic-heading-order.md
├── semantic-main-landmark.md
├── semantic-nav-landmark.md
├── semantic-no-section.md
├── a11y-focus-indicator.md
├── a11y-aria-patterns.md
├── a11y-image-alt.md
└── perf-image-srcset.md
```

各ルールファイルはfrontmatter（`title`・`impact`・`tags`）・if-then表・Incorrect/Correctコード例・不明時の確認項目で構成されます。新規ルールを追加する場合は `_template.md` を雛形とし、`_sections.md` のセクション分類にしたがってprefixを付けてください。
