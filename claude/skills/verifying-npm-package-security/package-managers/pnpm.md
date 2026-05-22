# pnpm参照ファイル

`SKILL.md`から参照されます。運用ルール（参照タイミング・正常系での独自考案禁止・問題発生時の自律対応）は`SKILL.md`の「パッケージマネージャー固有の操作は外部ファイル参照（必須ルール）」セクションに集約しています。

## 1. 検出ソース

- リポジトリルートに`pnpm-lock.yaml`が存在する場合
- または`package.json`の`packageManager`フィールドが`"pnpm@..."`で始まる場合

## 2. 推奨install / updateコマンド

| 操作 | コマンド |
|---|---|
| 通常追加 | `pnpm add <pkg>@<version>` |
| devDependency追加 | `pnpm add <pkg>@<version> -D` |
| 更新 | `pnpm update <pkg>` |

## 3. lockfile生成コマンドと副作用

| コマンド | 副作用 |
|---|---|
| `pnpm install --lockfile-only` | `pnpm-lock.yaml`のみ生成、`node_modules`は作らない |

## 4. ベースラインauditコマンドと抽出式

```bash
pnpm audit --json 2>/dev/null | jq '.metadata.vulnerabilities'
```

出力形はnpmと同じ形式です。

```json
{"info":0,"low":0,"moderate":0,"high":0,"critical":0}
```

実機検証済みです（pnpm 10系で確認しました。`.metadata.vulnerabilities`構造を持ちます）。

## 5. 観点1の対象パッケージadvisory抽出式

```bash
pnpm audit --json | jq '[.advisories[] | select(.module_name=="<pkg>")]'
```

pnpmは`.advisories`配列で、各要素が`.module_name`を持ちます。npmとはJSON構造が違うため、抽出式も別物です。

## 6. 観点5のpeer現状値取得方法

pnpm-lock.yamlはYAML形式でjqでは扱えません。

```bash
# node_modulesがあればnpm lsで取得（pnpmプロジェクトでもnpm lsは読めます）
if [ -d node_modules ]; then
  npm ls --json --depth=0 <peerDepName> 2>/dev/null \
    | jq -r '.dependencies["<peerDepName>"].version // empty'
fi
```

node_modulesがなくlockfile直読みも必要な場合は、現状peerが取れないものとしてHOLDに倒します。ユーザーに`pnpm install`を促す案内文を添えます。

YAMLパーサ（yq等）を別途導入してpnpm-lock.yamlを直読みする方法もありますが、本スキルでは追加依存を避けるためサポートしません。

## 7. 設定取得方法（実効値）

```bash
pnpm config get <key>
```

`pnpm config get`は実効値を返しますが、`--location`相当の引数を提供しないため、取得元の判別はできません。スナップショットには「実効値のみ」を記録し、取得元は「不明（実効値のみ）」と明示します。

判定に使うキーは`strict-peer-dependencies`、`auto-install-peers`です。

## 8. このパッケージマネージャー固有のエッジケース

`pnpm-workspace.yaml`が存在する場合、設定が`pnpm-workspace.yaml`の`packageExtensions`などにも書かれている可能性があります。設定キーはSKILL.mdのStep 2-1で`pnpm-workspace.yaml`を静的に読みます。

## 9. SKILL.mdからの参照箇所

| SKILL.mdのStep | このファイルの参照セクション |
|---|---|
| Step 2-2（設定実効値） | 7. 設定取得方法 |
| Step 3（installコマンド・audit準備） | 1, 2, 4 |
| Step 5（ベースライン取得） | 3, 4 |
| Step 6観点1（更新時CVE） | 5 |
| Step 6観点5（peer現状値） | 6 |
