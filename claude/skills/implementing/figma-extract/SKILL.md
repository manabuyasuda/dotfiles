---
name: figma-extract
description: >
  Figma MCPから実装に必要なデータを取得し、プロジェクトのCSSフレームワークに合わせてトークンを引き当て、マッピングファイルに記録するスキル。
  FigmaのURLやnode-idが渡されたとき、デザインと表示の差分を確認するとき、「スタイルが違う」「デザイン通りか確認して」「Figmaと比較して」のような依頼でも積極的に起動してください。
  Figma MCPを呼び出す前に、必ずこのスキルの手順にしたがってください。
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - AskUserQuestion
  - mcp__figma__get_design_context
  - mcp__figma__get_image
  - mcp__figma__get_metadata
  - mcp__playwright__screenshot
---

# figma-extract

このスキルは以下の3点を実施します。

1. Figma MCPから対象要素の全データを取得します
2. 取得したデータをマッピングファイルへ記録します（スタイル・テキスト・レイアウト）
3. 実装時の差分確認用スクリーンショットを保存します

実装はスコープに含まれません。

| ファイル | 内容 | 参照タイミング |
|---|---|---|
| `references/project-tokens.md` | フレームワーク別のFigmaトークン引き当て方法 | Step 1・Step 3 |
| `references/project-save-format.md` | 保存先・ファイルテンプレート・完成形サンプル | Step 2・Step 3 |
| `references/figma-output.md` | Figma出力の読み方（sparse処理・テキスト改行・レイアウト算出） | 毎Step |

## Step 1: CSSフレームワークを特定してトークンを把握する

以下のコマンドを上から順に実行し、最初に出力が返ってきたものがこのプロジェクトのCSSフレームワークです。特定したら、対応する設定ファイルを読んでトークン体系を把握します。

| コマンド | 出力があれば | 次に読むファイル |
|---|---|---|
| `ls tailwind.config.* 2>/dev/null` | Tailwind CSS | `tailwind.config.ts`（または`.js`）の`theme.extend` |
| `ls panda.config.* 2>/dev/null` | Panda CSS | `panda.config.ts`（または`.js`）の`tokens`/`semanticTokens` |
| `find src -name "*.css.ts" -maxdepth 4 \| head -3` | vanilla-extract | `contract.css.ts`または`vars.css.ts` |
| `find src -name "*.module.css" -o -name "*.module.scss" \| head -3` | CSS Modules | `variables.css`または`_variables.scss` |

Figmaトークンの引き当て方法は`references/project-tokens.md`を参照してください。

## Step 2: Figma MCPからデータを取得して記録する

`get_design_context`を呼び出し、取得した内容を加工せず保存します。保存先は`references/project-save-format.md`を参照してください。

ユーザーが渡したFigmaのURLからnode-idを取り出して`get_design_context`に渡します。URLがない場合はユーザーに確認します。返り値の読み方は`references/figma-output.md`を参照してください。

## Step 3: トークンを引き当ててマッピングファイルを更新する

Step 2で保存したマッピングファイルのトークン列を埋めます。引き当て方法は`references/project-tokens.md`を参照してください。完成条件は`references/project-save-format.md`を参照してください。

## Step 4: 差分確認用のスクリーンショットを保存する

`get_image`を呼び出し、`explore/{page-slug}/figma/screenshots/`に保存します。保存したファイルのパスをマッピングファイルの`### スクリーンショット`に記録します。

| 取得単位 | 用途 |
|---|---|
| ノード単位 | 対象コンポーネントの見た目を確認します |
| ページ・セクション全体 | レイアウト・隣接要素との関係を確認します |
