# npm参照ファイル

`SKILL.md`から参照されます。運用ルール（参照タイミング・正常系での独自考案禁止・問題発生時の自律対応）は`SKILL.md`の「パッケージマネージャー固有の操作は外部ファイル参照（必須ルール）」セクションに集約しています。

## 1. 検出ソース

- リポジトリルートに`package-lock.json`が存在する場合
- または`package.json`の`packageManager`フィールドが`"npm@..."`で始まる場合

## 2. 推奨install / updateコマンド

| 操作 | コマンド |
|---|---|
| 通常追加 | `npm install <pkg>@<version>` |
| devDependency追加 | `npm install <pkg>@<version> --save-dev` |
| 更新 | `npm update <pkg>` |

## 3. lockfile生成コマンドと副作用

| コマンド | 副作用 |
|---|---|
| `npm install --package-lock-only` | `package-lock.json`のみ生成、`node_modules`は作らない |

## 4. ベースラインauditコマンドと抽出式

```bash
npm audit --json 2>/dev/null | jq '.metadata.vulnerabilities'
```

出力形は以下の通りです。

```json
{"info":0,"low":0,"moderate":0,"high":0,"critical":0,"total":0}
```

実機検証済みです（npm 10系で確認しました）。

## 5. 観点1の対象パッケージadvisory抽出式

```bash
npm audit --json | jq '.vulnerabilities["<pkg>"] // empty | {name, severity, via}'
```

npm v7以降の`.vulnerabilities["<pkg>"]`は`.name` / `.severity`を直接持つオブジェクトで、`.module_name`フィールドは存在しません。空のときは`empty`で何も返さないので、判定側はnull扱いで「該当advisoryなし」と読みます。

## 6. 観点5のpeer現状値取得方法

```bash
# node_modulesがあればnpm lsで取得（トップレベル優先）
if [ -d node_modules ]; then
  npm ls --json --depth=0 <peerDepName> 2>/dev/null \
    | jq -r '.dependencies["<peerDepName>"].version // empty'
# なければpackage-lock.jsonから直接読みます
elif [ -f package-lock.json ]; then
  TOP=$(jq -r '.packages["node_modules/<peerDepName>"].version // empty' package-lock.json)
  if [ -n "$TOP" ]; then
    echo "$TOP"
  else
    jq -r '.packages | to_entries[] | select(.key | endswith("node_modules/<peerDepName>")) | .value.version' package-lock.json | head -1
  fi
fi
```

トップレベル優先→入れ子フォールバックの順で読みます。

## 7. 設定取得方法（実効値と取得元）

npmは多階層configをサポートし、`--location`指定でスコープ別の値を取得できます。

```bash
# 実効値（マージ後）
npm config get <key>
# スコープ別の値
npm config get <key> --location=project
npm config get <key> --location=user
npm config get <key> --location=global
```

スコープ別の値がdefault（多くの場合`false` / 空文字）でなくなる最初のスコープが「取得元」です。3スコープすべてdefaultなら「default（npm組み込み）」として記録します。

`npm config get`の戻り値は常に文字列です。boolean値も`"true"` / `"false"`の文字列として返るため、比較は`[ "$val" = "true" ]`のように文字列比較で行います。

判定に使うキーは以下の通りです。

- `legacy-peer-deps`
- `strict-peer-dependencies`
- `auto-install-peers`
- `tag`
- `save-prefix`
- `save-exact`

## 8. このパッケージマネージャー固有のエッジケース

とくにありません。npmのコマンド・JSON形式は安定しています。

## 9. SKILL.mdからの参照箇所

| SKILL.mdのStep | このファイルの参照セクション |
|---|---|
| Step 2-2（設定実効値） | 7. 設定取得方法 |
| Step 3（installコマンド・audit準備） | 1, 2, 4 |
| Step 5（ベースライン取得） | 3, 4 |
| Step 6観点1（更新時CVE） | 5 |
| Step 6観点5（peer現状値） | 6 |
