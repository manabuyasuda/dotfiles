# CSSフレームワーク別: トークンの適用方法

`figma-extract`が引き当てたトークン（マッピングファイルのトークン列）を、実コードへ適用するための記法をまとめます。

## Step 1: project-instructions.mdの該当見出しを確認する

最初に`references/project-instructions.md`の以下の見出しを確認します。

- 「スタイル実装の規約」
- 「インポートパス・パスエイリアス」

記載があればそれを最優先で適用します。記載があれば以降のStepは参考情報として扱い、判断に迷ったときのみ参照します。記載がなければStep 2以降の手順で自律判断します。

## Step 2: CSSフレームワークを特定する

以下のコマンドを上から順に実行し、最初に出力が返ってきたものがプロジェクトのCSSフレームワークです。

| コマンド | 出力があれば |
|---|---|
| `ls tailwind.config.* 2>/dev/null` | Tailwind CSS |
| `ls panda.config.* 2>/dev/null` | Panda CSS |
| `find src -name "*.css.ts" -maxdepth 4 \| head -3` | vanilla-extract |
| `find src -name "*.module.css" -o -name "*.module.scss" \| head -3` | CSS Modules |

特定したフレームワークの該当セクションに進みます。

## Tailwind CSSプロジェクトの場合

マッピングファイルのトークン列に記録されたクラス名をそのまま`className`で適用します。

```tsx
// マッピングファイルのトークン列: text-sm font-bold text-gray-900 px-2
<p className="text-sm font-bold text-gray-900 px-2">テキスト例</p>
```

### 既存パターンを優先する

新しいクラスを使う前に、既存コンポーネントで同じCSS変数がどのクラスに変換されているかを確認します。プロジェクト固有の`theme.extend`で独自命名されているケースがあります。

```bash
grep -rn "text-sm\|font-bold" src/ --include="*.tsx" | head
```

### arbitrary valueの扱い

`tailwind.config`にトークンが存在せず、マッピングファイルが`w-[347px]`のようなarbitrary valueで記録されている場合は、そのまま適用します。ただし、繰り返し使われる値であれば`theme.extend`への追加を検討します。

## Panda CSSプロジェクトの場合

マッピングファイルのトークン列に記録された`token('colors.fg.default')`のような記法を、`css()`または`styled`に渡します。

```tsx
import { css } from 'styled-system/css';

// マッピングファイルのトークン列: token('colors.fg.default') / token('spacing.sm')
const label = css({
  color: 'fg.default',
  paddingBlock: 'sm',
  paddingInline: 'sm',
  textStyle: 'body.sm.bold',
});
```

`token('colors.fg.default')`を直接書く形（`color: token('colors.fg.default')`）も使えます。プロジェクト内の既存パターンに合わせます。

```bash
grep -rn "css({" src/ --include="*.tsx" --include="*.ts" | head
```

## vanilla-extractプロジェクトの場合

`.css.ts`ファイル内で`style()` APIを使い、マッピングファイルのトークン列に記録された`vars.fg.default` / `space.sm`のような参照を適用します。

```ts
// label.css.ts
import { style } from '@vanilla-extract/css';
import { vars } from '@/styles/generated/contract.css';
import { space, typography } from '@/styles';

export const label = style({
  ...typography['body-sm-bold'],
  color: vars.fg.default,
  paddingBlock: space.sm,
  paddingInline: space.sm,
});
```

インポートパスはプロジェクトごとに異なるため、既存の`.css.ts`ファイルを1〜2件読んで実際のパスを確認します。

```bash
grep -rn "from '@/styles\|from '~/styles" src/ --include="*.css.ts" | head
```

## CSS Modulesプロジェクトの場合

`.module.css` / `.module.scss`でCSS変数を`var(--token-name)`として適用し、コンポーネント側ではクラス名を当てます。

```css
/* Label.module.css */
.label {
  color: var(--fg-default);
  padding-block: var(--spacing-sm);
  padding-inline: var(--spacing-sm);
  font-size: var(--font-size-sm);
  font-weight: var(--font-weight-bold);
}
```

```tsx
import styles from './Label.module.css';

<p className={styles.label}>テキスト例</p>
```

グローバルCSS変数の定義場所（`src/styles/variables.css`等）は、既存ファイルを1件読んで確認します。

## 適用時の共通注意事項

- マッピングファイルの`状態`列が`✓`になっている行のみ実装に反映します。`-`や空欄が残っていればfigma-extractに戻して埋め直します
- フォールバック値（`var(--fg/default, #212529)`の`#212529`部分）はそのまま使いません。トークン参照が解決できないときの仮値です
- 同じトークンを複数箇所で使う場合は既存コンポーネントの記法を踏襲します（grepで既存パターンを必ず確認します）
