# Figmaから取得したデータの保存形式

## 保存先ディレクトリ

```
explore/
└── {page-slug}/
    └── figma/
        ├── raw/               ← get_design_contextの返り値
        │   ├── _index.json    ← 取得状況を管理するインデックス
        │   ├── {nodeId}.txt   ← 完全レスポンスのキャッシュ
        │   └── {nodeId}.xml   ← sparseレスポンスのキャッシュ
        ├── screenshots/       ← get_screenshotのスクリーンショット
        └── {root-node-id}.md  ← マッピングファイル
```

## Step 1: ページスラグを決める

Figmaのページ名全体をケバブケースに変換してスラグにします。`_lightMode`/`_darkMode`などのサフィックスも含めて変換することで、モードの異なるページが同じスラグになるのを防ぎます。決めたスラグが`explore/{page-slug}/`の`{page-slug}`に対応します。

| Figmaページ名 | `{page-slug}` |
|---|---|
| `Top-sp_lightMode` | `top-sp-light-mode` |
| `Top-sp_darkMode` | `top-sp-dark-mode` |
| `ProductDetail-shop_lightMode` | `product-detail-shop-light-mode` |

## Step 2: 返り値をraw/に保存する

### Step 2-1: ディレクトリと`_index.json`を準備する

`explore/{page-slug}/figma/raw/`と`explore/{page-slug}/figma/screenshots/`がなければ作成します。

`_index.json`がなければ以下のテンプレートで新規作成します。

```json
{
  "meta": {
    "fileKey": "<fileKey>",
    "rootNodeId": "<rootNodeId>",
    "fetchedAt": "YYYY-MM-DD"
  },
  "tree": {},
  "fetchedNodes": [],
  "pendingNodes": [],
  "userSkippedNodes": [],
  "jsxNodes": {},
  "componentNodes": []
}
```

| フィールド | 説明 |
|---|---|
| `meta.fileKey` | FigmaファイルURL（`figma.com/design/{fileKey}/...`）の`{fileKey}` |
| `meta.rootNodeId` | 取得を開始するルートノードのID |
| `meta.fetchedAt` | 取得開始日 |
| `tree` | 取得済みノードの情報（初期は空） |
| `fetchedNodes` | 取得済みノードIDの一覧（初期は空） |
| `pendingNodes` | 取得できていない子ノードのID（初期は空） |
| `userSkippedNodes` | ユーザーが取得しないと判断したノードID（初期は空）。エージェントは処理中に書き込まない |
| `jsxNodes` | Pass 1: `.txt`を取得したときにgrepしたすべての`data-node-id`（初期は空オブジェクト） |
| `componentNodes` | Pass 2: コンポーネント境界と判断したノード一覧（初期は空配列） |

`_index.json`がある場合は`fetchedNodes`を確認します。記録済みのノードは再取得する必要がありません。`pendingNodes`が残っていればそこから再開します。

### Step 2-2: `get_design_context`を呼び出し、返り値を加工せず保存する

返り値は`explore/{page-slug}/figma/raw/`に保存します。

| 拡張子 | 返り値の種類 | 内容 |
|---|---|---|
| `.txt` | 完全レスポンス | JSXコード（`export default function`を含む） |
| `.xml` | sparseレスポンス | XML属性リスト・座標・子ノードIDのみ |

### Step 2-3: `_index.json`を更新する

次のルールで更新します。

- `tree`にノードを追加します（`rawFile`には保存したファイル名を設定します）
- `fetchedNodes`にノードIDを追加します
- `.xml`の場合のみ、`children`の値を`pendingNodes`に追加します
- `.txt`の場合のみ、Pass 1としてJSX内のすべての`data-node-id`をgrepして`jsxNodes[nodeId]`に記録します

### Pass 1（スクリプトが自動処理）

`.txt`を受け取ったら、SKILL.mdの手順に従い`update-jsx-nodes.js`を実行します。
スクリプトが`data-node-id`と`data-name`の対応付けを含めて`jsxNodes`を自動更新します。
手動grepは使いません。

更新後の`jsxNodes`の形式は以下の通りです。

```json
"jsxNodes": {
  "9856:14163": [
    { "nodeId": "9856:14164", "name": null },
    { "nodeId": "9856:14165", "name": "heading" },
    { "nodeId": "9856:16944", "name": null },
    { "nodeId": "9856:16914", "name": null },
    { "nodeId": "9856:16915", "name": "heading" }
  ]
}
```

`name`はJSX内の`data-name`属性の値です。`data-name`がなければ`null`を設定します。

### Pass 2（コンポーネント境界の判断）

全ノードの取得が完了した後（`pendingNodes`が空になった後）に1回だけ実行します。

`jsxNodes`のすべてのエントリを参照し、以下のシグナルを持つノードを`componentNodes`に追加します。

| シグナル | 具体例 |
|---|---|
| `data-name`がコンポーネントらしい名前（PascalCase・英単語の複合語） | `"ButtonTextSecondary"` |
| 同一構造の兄弟ノードが繰り返される（リストアイテム） | TimelineRow-1〜5の各行 |
| 子孫に`data-name="heading"`を持つ独立ブロック | 「開催場一覧」「お知らせ」を内包するラッパー |

判断した根拠（どのシグナルに該当するか）を`componentNodes`のエントリに`reason`として記録します。

```json
"componentNodes": [
  { "nodeId": "9856:14164", "name": "VenueList", "reason": "子孫にheadingを持つ独立ブロック" },
  { "nodeId": "9856:16914", "name": "NoticeList", "reason": "子孫にheadingを持つ独立ブロック" }
]
```

`name`はFigmaの`data-name`がある場合はその値を使い、なければエージェントがJSXから推測して命名します。

完全レスポンス（`.txt`）を取得した直後のサンプルです。

```json
{
  "tree": {
    "1111:11111": {
      "name": "ticker",
      "type": "instance",
      "parent": null,
      "children": [],
      "rawFile": "1111-11111.txt"
    }
  },
  "fetchedNodes": ["1111:11111"],
  "pendingNodes": []
}
```

続けて別のノード（sparse → `.xml`）を取得した直後のサンプルです。

```json
{
  "tree": {
    "1111:11111": { "...": "..." },
    "2222:22222": {
      "name": "Top-sp_lightMode",
      "type": "frame",
      "parent": null,
      "children": ["3333:33333", "4444:44444"],
      "rawFile": "2222-22222.xml"
    }
  },
  "fetchedNodes": ["1111:11111", "2222:22222"],
  "pendingNodes": ["3333:33333", "4444:44444"]
}
```

### Step 2-4: `pendingNodes`が空になるまで繰り返す

`pendingNodes`に残っているノードIDを順に取得します（Step 2-2に戻る）。`pendingNodes`が空になれば取得が完了します。

## Step 3: マッピングファイルを作成する

保存先は`explore/{page-slug}/figma/{root-node-id}.md`です。トークン列を空欄のまま保存します。

```markdown
# {root-node-id}

取得日時: YYYY-MM-DD
ページスラグ: {page-slug}

## {NodeName}（{node-id}）

### スタイル

| プロパティ | Figma値 | トークン | 状態 |
|---|---|---|---|
| typography | body/sm/1line/bold | | |
| color | var(--fg/default) | | |
| paddingBlock | var(--spacing/sm) | | |
| paddingInline | var(--spacing/sm) | | |

### テキスト

| ノード名 | テキスト内容 | 表示行数 |
|---|---|---|
| primaryText | "テキスト例" | 1行 |
| secondaryText | "テキスト例2" | 1行 |

### アイコン

| ノード名 | Figmaコンポーネント名 | 対応するアイコン | サイズ（w×h） | fill色 | トークン |
|---|---|---|---|---|---|
| icon | chevron-right | （ライブラリのキー名） | 16×16 | var(--fg/default) | |

### 画像

| ノード名 | 用途 | サイズ（w×h） | object-fit |
|---|---|---|---|
| thumbnail | サムネイル画像 | 343×200 | cover |

### マークアップ役割

figma-implementのStep 5で確定した各要素のタグ・属性・構造を記録します。figma-extractでは空欄のまま残します。

| 要素 | タグ | 属性・備考 |
|---|---|---|
| （要素名） | （タグ名） | （aria-label・role・href等、付与する属性と理由） |

### スクリーンショット

| ファイルパス | 取得単位 |
|---|---|
| explore/{page-slug}/figma/screenshots/{root-node-id}.png | ページ全体 |
| explore/{page-slug}/figma/screenshots/{fetched-node-id}.png | fetchedNodes単位（親コンテキスト） |
| explore/{page-slug}/figma/screenshots/{component-node-id}.png | componentNodes単位（コンポーネント単体） |
```

## 完成条件

以下をすべて満たしていれば完了です。満たしていなければトークンの引き当てに戻ります。

- Figma出力に含まれるすべてのノードが`## NodeName（node-id）`の見出しとして存在しています
- すべての行のトークン列が埋まっています（空欄がありません）
- すべてのテキスト行が記録されています
- アイコンノードが`### アイコン`に記録されています
- 画像ノードが`### 画像`に記録されています
- `_index.json`の`jsxNodes`に`.txt`で取得したすべてのノードのPassが記録されています
- `_index.json`の`componentNodes`にPass 2の判断結果が記録されています
- スクリーンショットがルートノード・`componentNodes`の2種類揃っています
- `### マークアップ役割`セクションが各`## NodeName`に存在しています（figma-extractの時点では空欄でかまいません。figma-implementのStep 5で埋めます）

## 完成形サンプル

```markdown
# {root-node-id}

取得日時: 2026-05-15

## SomeComponent（5555:55555）

### スタイル

| プロパティ | Figma値 | トークン | 状態 |
|---|---|---|---|
| typography | body/sm/1line/bold | （フレームワーク別のトークン記法） | ✓ |
| color | var(--fg/default) | （フレームワーク別のトークン記法） | ✓ |
| paddingBlock | var(--spacing/sm) | （フレームワーク別のトークン記法） | ✓ |
| paddingInline | var(--spacing/sm) | （フレームワーク別のトークン記法） | ✓ |

### テキスト

| ノード名 | テキスト内容 | 表示行数 |
|---|---|---|
| primaryText | "テキスト例" | 1行 |
| secondaryText | "テキスト例2" | 1行 |

### アイコン

| ノード名 | Figmaコンポーネント名 | 対応するアイコン | サイズ（w×h） | fill色 | トークン |
|---|---|---|---|---|---|
| icon | chevron-right | （フレームワーク別のアイコン記法） | 16×16 | var(--fg/default) | （フレームワーク別のトークン記法） |

### 画像

| ノード名 | 用途 | サイズ（w×h） | object-fit |
|---|---|---|---|
| thumbnail | サムネイル画像 | 343×200 | cover |

### マークアップ役割

| 要素 | タグ | 属性・備考 |
|---|---|---|
| cardRoot | `<a>` | `href="/items/123"` — カード全体がリンク |
| cardTitle | `<h3>` | — |
| cardList | `<ul>` | `list-style: none` |
| cardItem | `<li>` | — |

### スクリーンショット

| ファイルパス | 取得単位 |
|---|---|
| explore/{page-slug}/figma/screenshots/5555-55555.png | ノード単位 |
```
