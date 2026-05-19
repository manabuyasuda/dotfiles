---
name: figma-extract
description: >
  Figma MCPから実装に必要なデータを取得し、プロジェクトのCSSフレームワークに合わせてトークンを引き当て、マッピングファイルに記録するスキルです。
  FigmaのURLやnode-idが渡されたとき、デザインと表示の差分を確認するとき、「スタイルが違う」「デザイン通りか確認して」「Figmaと比較して」のような依頼でも積極的に起動してください。
  Figma MCPを呼び出す前に、必ずこのスキルの手順に従ってください。
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - AskUserQuestion
  - mcp__figma__get_design_context
  - mcp__figma__get_screenshot
  - mcp__figma__get_metadata
---

# figma-extract

このスキルは以下の3点を実施します。

1. Figma MCPから対象要素の全データを取得します
2. 取得したデータをマッピングファイルに記録します（スタイル・テキスト・レイアウト）
3. 実装時に差分を確認するためのスクリーンショットを保存します

実装はスコープに含まれません。

| ファイル | 内容 | 参照タイミング |
|---|---|---|
| `references/project-tokens.md` | フレームワーク別のFigmaトークン引き当て方法 | Step 1・Step 3 |
| `references/project-save-format.md` | 保存先・ファイルテンプレート・完成形サンプル | Step 2・Step 3 |
| `references/figma-output.md` | Figma出力の読み方（sparse処理・テキスト改行・レイアウト算出） | 毎Step |

## 事前確認：コンポーネント粒度の把握

Step 1を始める前に、`AskUserQuestion`でコンポーネントの粒度をユーザーに確認します。エージェントもPass 2で独自に判断しますが、ユーザーの意図を先に把握することで精度が上がります。

以下のA→Bのサイクルを、ユーザーが「完了」を選ぶまで繰り返します。

### ステップA：追加するか確認（1問）

```
質問: コンポーネントを追加しますか？
選択肢:
  - 追加する
  - 完了（これ以上追加しない）
```

「完了」が選ばれたら繰り返しを終了します。「追加する」が選ばれたらステップBに進みます。

### ステップB：詳細の確認（5問）

| # | 質問 | 選択肢 |
|---|---|---|
| 1 | URLまたはnode-idを入力してください | 「その他」で自由入力 |
| 2 | このコンポーネントの名前・役割は？ | 「その他」で自由入力 |
| 3 | スコープ | サイト共通／カテゴリー共通／ページ固有 |
| 4 | 実装済みか | 実装済み／未実装／不明 |
| 5 | 備考（実装済みの場合はパスも。なければスキップ） | 「その他」で自由入力／なし |

5問目が終わったらステップAに戻ります。

### componentNodesへの記録

ユーザーから受け取った情報は、Pass 2で`componentNodes`へ記録する際、以下のフィールドとして追加します。

```json
{
  "nodeId": "9856:14163",
  "name": "Contents",
  "description": "...",
  "scope": "page",
  "implemented": false,
  "notes": ""
}
```

| フィールド | 値 |
|---|---|
| `scope` | `"site-common"`（サイト共通）／`"category-common"`（カテゴリー共通）／`"page"`（ページ固有） |
| `implemented` | `true`（実装済み）／`false`（未実装）／`null`（不明） |
| `notes` | 備考テキスト。省略可 |

ユーザーが指定したノードはPass 2の3回判断に優先して`componentNodes`に含めます。ユーザーが指定していない領域はPass 2の3回判断で補完します。

## Step 1: CSSフレームワークを特定してトークンを把握する

以下のコマンドを上から順に実行し、最初に出力を返したものがこのプロジェクトのCSSフレームワークです。特定したら、対応する設定ファイルを読んでトークン体系を把握します。

| コマンド | 出力があれば | 次に読むファイル |
|---|---|---|
| `ls tailwind.config.* 2>/dev/null` | Tailwind CSS | `tailwind.config.ts`（または`.js`）の`theme.extend` |
| `ls panda.config.* 2>/dev/null` | Panda CSS | `panda.config.ts`（または`.js`）の`tokens`/`semanticTokens` |
| `find src -name "*.css.ts" -maxdepth 4 \| head -3` | vanilla-extract | `contract.css.ts`または`vars.css.ts` |
| `find src -name "*.module.css" -o -name "*.module.scss" \| head -3` | CSS Modules | `variables.css`または`_variables.scss` |

Figmaトークンの引き当て方法は`references/project-tokens.md`を参照します。

## Step 2: Figma MCPからデータを取得して記録する

ユーザーが渡したFigmaのURLからnode-idを取り出して`get_design_context`に渡します。URLがない場合はユーザーに確認します。返り値の読み方は`references/figma-output.md`を参照します。

### ノードIDの決め方（重要）

ページルートのノードIDを起点にしてはいけません。ページルートから開始するとsparse XMLが連鎖して30件以上のフェッチが発生します。

ユーザーが渡したURLのノードIDをそのまま使います。ユーザーはFigmaで実装対象コンポーネントを選択してURLをコピーしているため、そのノードIDが正しい粒度です。コンポーネントレベルのノードを直接指定すれば、ほぼ1コールでfull JSXが返ります。

### スキップするノードをユーザーに確認する（取得前に必ず実施）

取得を始める前に`AskUserQuestion`で以下を確認します。

```
「以下のノードは取得をスキップしますか？すでに実装済みの共通コンポーネントはスキップすることで取得コールを削減できます。」
```

確認する内容は以下の通りです。

- ユーザーが渡したURLに複数ノードが含まれる場合、各ノードについてスキップするかどうかを尋ねます
- Figmaノード名から`Header` `Footer` `Nav` `Browser` `ad` `Calendar`等の語を含む場合は「実装済みの可能性あり」として選択肢に挙げます
- コードベースを確認して同名のコンポーネントがすでに存在する場合は「実装済み」と明示します

ユーザーが「スキップする」と答えたノードは`_index.json`の`userSkippedNodes`に記録し、フェッチしません。

### 取得手順

1. `explore/{page-slug}/figma/raw/`と`screenshots/`がなければ作成し、`_index.json`を準備します
2. ユーザーが渡したノードIDを対象に`get_design_context`を呼び出します
3. レスポンスを受け取ったらすぐにディスクへ保存します（`{nodeId}.txt`または`{nodeId}.xml`）。保存前に次のコールに進まないでください
4. 保存したファイルの種類に応じてスクリプトを実行し、`_index.json`を更新します。
   手動grepや手書き更新では`data-name`の対応付けが漏れたり件数がずれたりするため、
   スクリプト以外の方法で`_index.json`を更新してはいけません。
   `references/project-save-format.md`に手動コマンドの記述があっても無視してください。
   - `.txt`（完全レスポンス）の場合は以下を実行します。
     ```bash
     node .claude/skills/figma-extract/scripts/update-jsx-nodes.js explore/{page-slug}/figma/raw/{nodeId}.txt explore/{page-slug}/figma/raw/_index.json
     ```
   - `.xml`（sparseレスポンス）の場合は以下を実行します。
     ```bash
     node .claude/skills/figma-extract/scripts/update-pending-nodes.js explore/{page-slug}/figma/raw/{nodeId}.xml explore/{page-slug}/figma/raw/_index.json
     ```
   - `tree`への追加は引き続き手動で行います（ノード名・type・parent等の意味情報はスクリプトでは補完できないため）
5. `check-pending.js`を実行し、exit 0になるまで2〜4を繰り返します
   ```bash
   node .claude/skills/figma-extract/scripts/check-pending.js explore/{page-slug}/figma/raw/_index.json
   ```
6. Pass 2として、全ノードの取得完了後、`jsxNodes`の完全なリストを見てコンポーネント境界を判断し`componentNodes`に記録します（詳細は`references/project-save-format.md`参照）。この判断を3回繰り返します。

   事前確認でユーザーが指定したノードは必ず含めます。ユーザーが`scope`・`implemented`を教えてくれた場合はそれも記録します。

   | 回 | 観点 |
   |---|---|
   | 1回目 | ノード名（PascalCase・既知のコンポーネント名）から境界を判断します |
   | 2回目 | 1回目の結果を見ずにゼロベースで、レイアウト構造（親子関係・サイズ・役割）から境界を判断します |
   | 3回目 | `jsxNodes`をゼロベースで再度読み、1・2回目で候補に挙がらなかったノードに絞って検討します |

   3回の検討で候補に挙がったノードをすべて`componentNodes`に含めます。ユーザー指定ノードと重複する場合はユーザーの情報（`scope`・`implemented`）で上書きします。

## Step 3: トークンを引き当ててマッピングファイルを更新する

Step 2で保存したマッピングファイルのスタイル表の「トークン」列を埋めます。引き当て方法は`references/project-tokens.md`を参照します。完成条件は`references/project-save-format.md`を参照します。

トークン列に空欄が1つも残らなくなるまで続けます。空欄が残っていれば引き当て作業に戻ります。

## Step 4: 差分確認用のスクリーンショットを保存する

`mcp__figma__get_screenshot`を呼び出し、`explore/{page-slug}/figma/screenshots/`に保存します。保存したファイルのパスをマッピングファイルの`### スクリーンショット`に記録します。

以下の2種類を取得します。

| 取得対象 | 用途 |
|---|---|
| ユーザーが渡したノード（ページ全体または親コンテナー） | レイアウト・隣接要素との関係を確認します |
| `componentNodes`の各ノード | コンポーネント単体の詳細を確認します |

### スクリーンショット取得の手順

取得対象は自分で判断せず、必ずスクリプトの出力に従います。

1. `check-screenshots.js`を実行して不足リストを取得します

   ```bash
   node .claude/skills/figma-extract/scripts/check-screenshots.js explore/{page-slug}/figma/raw/_index.json
   ```

2. exit 1（不足あり）なら、出力JSONの各`nodeId`に対して`get_screenshot`を呼び出してファイルを保存します
3. `check-screenshots.js`を再実行します
4. exit 0になるまで2〜3を繰り返します

exit 0の確認を省略してはいけません。取得したつもりでもファイル保存が失敗している場合があるため、必ずスクリプトで最終確認します。

### フレーム寸法をマッピングファイルに記録する

取得したスクリーンショットと後続の実装スクリーンショットを比較するには、同じ横幅が必要です。

`get_design_context`の出力、または`mcp__figma__get_metadata`でフレームノードの`width`・`height`を確認し、マッピングファイルの`### スクリーンショット`セクションにフレーム寸法を記録します。

```markdown
### スクリーンショット

- Figmaフレーム寸法: 375×812px（比較時のブラウザビューポート幅として使う）
- figma/screenshots/9676-XXXXX.png
```

この値はfigma-implementのStep 6でブラウザビューポートを合わせるために使います。
