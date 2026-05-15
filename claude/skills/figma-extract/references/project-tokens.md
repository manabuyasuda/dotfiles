# CSSフレームワーク別: トークンの引き当て方法

Step 1で特定したフレームワークの該当セクションを参照してください。フォールバック値をそのままトークンとして使わず、トークンが見つかったらトークンキーで記録します。

## Tailwind CSSプロジェクトの場合

FigmaのCSS変数のパスを、Tailwindのクラス名に変換します。

1. Figmaの出力から`var(--typography/body/sm/bold/font-size, 14px)`のようなCSS変数のパスを確認します
2. `tailwind.config`の`fontSize`キーで対応するクラスを探します
3. `text-sm`（14px）などのクラス名に変換します

| Figmaのvar | Tailwindクラス | 確認箇所 |
|---|---|---|
| `var(--fg/default)` | `text-gray-900`など | theme.colors |
| `var(--spacing/sm)` | `p-2`など | theme.spacing |
| タイポグラフィ | `text-sm font-bold`など | theme.fontSize / fontWeight |

対応するクラスが見つからない場合は、以下の順で対処します。

1. `tailwind.config`の`theme.extend`にトークンが登録されていないか確認します
2. 既存コンポーネントで同じCSS変数がどのクラスに変換されているかを確認します
3. どちらでも見つからない場合は、arbitrary value（`w-[347px]`など）をマッピングファイルに記録します

## Panda CSSプロジェクトの場合

`panda.config`の`semanticTokens`または`tokens`でパスを確認し、`token()`に変換します。

| Figmaのvar | Panda CSSのトークン | 確認箇所 |
|---|---|---|
| `var(--fg/default)` | `token('colors.fg.default')` | semanticTokens |
| `var(--spacing/sm)` | `token('spacing.sm')` | tokens.spacing |

## vanilla-extractプロジェクトの場合

キー名はプロジェクト独自の変換ルールで決まるため、`contract.css.ts`や`vars.css.ts`を開いて実際のキー名を確認します。

| Figmaのvar | vanilla-extractの変数 |
|---|---|
| `var(--fg/default, #212529)` | `vars.fg.default` |
| `var(--typography/body/sm/bold/font-size, 14px)` | `typography["body-sm-bold"]` など（キー名はプロジェクト依存） |

## CSS Modulesプロジェクトの場合

`var(--fg-default, #212529)`は、グローバルCSSの変数定義と照合し、`var(--fg-default)`として使います。

## 引き当てに迷ったとき

上記の対応表に載っていないトークンや、パスからクラス名が判断しにくい場合は、既存のコンポーネントで同じCSS変数がどのクラス・トークンに変換されているかを確認します。そのプロジェクト固有のマッピングパターンが手がかりになります。
