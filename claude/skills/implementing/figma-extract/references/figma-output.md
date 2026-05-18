# Figma出力の読み方

## sparseレスポンスの処理

`get_design_context`はノードが大きい場合、完全なJSXコードではなくsparse（座標・子ID一覧のみのXML）を返します。

| 返り値の種類 | 判定方法 |
|---|---|
| 完全レスポンス | `export default function`を含むJSXコード |
| sparse | XML属性リスト・座標情報のみ |

取得を始める前に`_index.json`を確認します。記録済みのノードは再取得不要です。

sparseを受け取ったら、以下の手順で子ノードを分割取得します。

```
1. ルートノード取得 → sparseなら子node-idを _index.json に記録、rawFileは {nodeId}.xml
2. 各子ノードを get_design_context で取得
3. 完全レスポンスが返れば → {nodeId}.txt に保存して _index.json を更新
4. sparseが返れば → 子node-idを記録してさらに取得（再帰）
5. pendingNodes が空になれば取得完了
```

## テキストの改行

Figmaのテキストノードに`\n`（改行）が含まれると、`get_design_context`の出力では複数の`<p>`タグに展開されます。Figmaで「テキストとしてコピー」すると改行が消えて1行に見えますが、JSX上では複数行になっています。テキスト表には展開後の各`<p>`を別行として記録します。

```
// Figmaから文字列コピー
"ラベルA サブラベルB"  ← 改行が消えて1行に見える

// get_design_context の出力
<p>ラベルA</p>
<p>サブラベルB</p>  ← 2行に展開されている
```

| ノード名 | テキスト内容 | 表示行数 |
|---|---|---|
| headerCell | "ラベルA" / "サブラベルB" | 2行 |

## コンテナーとテキストノードの区別

タイポグラフィは`data-node-id`で特定したテキストノード（`<p>` / `<span>`）自身のスタイルから読みます。Figmaの出力では親コンテナーと子テキストが別ノードになっており、コンテナーに`leading-[0]`が含まれる場合があります。これはレイアウト上の配置トリックであり、テキストのlineHeightではありません。

```
親コンテナー: leading-[0]    ← 配置トリック（タイポグラフィとして読まない）
  子テキスト: leading-none  ← こちらが実際のlineHeight
```

## レイアウトの算出

対象ノードの座標（x, y, width, height）と親ノードのサイズを照合して余白を算出します。

- `get_design_context`がsparseを返した場合は、そのXML内の座標情報を使います
- 完全レスポンスが返った場合、親ノードのサイズが含まれていないことがあります。その場合は`get_metadata`で親ノードを取得します

```
親width=375、子x=16 width=343
  → 左余白=16、右余白=375-343-16=16 → paddingInline: 16px（左右均等）

親width=375、子x=0 width=291
  → 左余白=0 → 左寄せ、または親に別の要素が並んでいる

親width=375、子x=329 width=46
  → 左余白=329 → 右寄せ（marginInlineStart: auto など）

親height=82、子y=16 height=50
  → 上余白=16、下余白=82-50-16=16 → paddingBlock: 16px（上下均等）
```

算出結果はマッピングファイルのスタイル表に記録します。

| プロパティ | Figma値 | トークン | 状態 |
|---|---|---|---|
| layout | 親375px中 x=16 w=343 → paddingInline 16px | | |
