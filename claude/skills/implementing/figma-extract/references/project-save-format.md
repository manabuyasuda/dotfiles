# Figmaから取得したデータの保存形式

## 保存先ディレクトリ

```
explore/
└── {page-slug}/
    └── figma/
        ├── raw/               ← get_design_context の返り値
        │   ├── _index.json    ← 取得状況を管理するインデックス
        │   ├── {nodeId}.txt   ← 完全レスポンスのキャッシュ
        │   └── {nodeId}.xml   ← sparseレスポンスのキャッシュ
        ├── screenshots/       ← get_image のスクリーンショット
        └── {root-node-id}.md  ← マッピングファイル
```

## Step 1: ページスラグを決める

Figmaのページ名全体をケバブケースに変換してスラグにします。`_lightMode`/`_darkMode`などのサフィックスも含めて変換することで、モードが異なるページが同じスラグになるのを防ぎます。決めたスラグが`explore/{page-slug}/`の`{page-slug}`になります。

| Figmaページ名 | `{page-slug}` |
|---|---|
| `Top-sp_lightMode` | `top-sp-light-mode` |
| `Top-sp_darkMode` | `top-sp-dark-mode` |
| `ProductDetail-shop_lightMode` | `product-detail-shop-light-mode` |

## Step 2: 返り値を raw/ に保存する

### Step 2-1: ディレクトリと`_index.json`を準備する

`explore/{page-slug}/figma/raw/`と`explore/{page-slug}/figma/screenshots/`が存在しなければ作成します。

`_index.json`が存在しなければ以下のテンプレートで新規作成します。

```json
{
  "meta": {
    "fileKey": "<fileKey>",
    "rootNodeId": "<rootNodeId>",
    "fetchedAt": "YYYY-MM-DD"
  },
  "tree": {},
  "fetchedNodes": [],
  "pendingNodes": []
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

`_index.json`が存在する場合は`fetchedNodes`を確認します。記録済みのノードは再取得する必要はありません。`pendingNodes`が残っていればそこから再開します。

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

保存先は`explore/{page-slug}/figma/{root-node-id}.md`です。トークン列は空欄のまま保存します。

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

### スクリーンショット

| ファイルパス | 取得単位 |
|---|---|
| explore/{page-slug}/figma/screenshots/{node-id}.png | ノード単位 |
```

## 完成条件

以下がすべて満たされていれば完了です。満たされていなければトークンの引き当てに戻ります。

- Figma出力に含まれるすべてのノードが`## NodeName（node-id）`の見出しとして存在する
- すべての行のトークン列が埋まっている（空欄がない）
- すべてのテキスト行が記録されている
- アイコンノードが`### アイコン`に記録されている
- 画像ノードが`### 画像`に記録されている

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

### スクリーンショット

| ファイルパス | 取得単位 |
|---|---|
| explore/{page-slug}/figma/screenshots/5555-55555.png | ノード単位 |
```
