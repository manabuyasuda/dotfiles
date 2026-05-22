# yarn v1 (Classic)参照ファイル

`SKILL.md`から参照されます。運用ルール（参照タイミング・正常系での独自考案禁止・問題発生時の自律対応）は`SKILL.md`の「パッケージマネージャー固有の操作は外部ファイル参照（必須ルール）」セクションに集約しています。

## 1. 検出ソース

- リポジトリルートに`yarn.lock`が存在する場合
- かつ`.yarnrc.yml`が存在しない場合（存在する場合はyarn berry → `yarn-berry.md`を参照）
- または`package.json`の`packageManager`フィールドが`"yarn@1.*"`で始まる場合
- または`yarn --version`の出力が`1.*`の場合

## 2. 推奨install / updateコマンド

| 操作 | コマンド |
|---|---|
| 通常追加 | `yarn add <pkg>@<version>` |
| devDependency追加 | `yarn add <pkg>@<version> --dev` |
| 更新 | `yarn upgrade <pkg>@<version>` |

## 3. lockfile生成コマンドと副作用

| コマンド | 副作用 |
|---|---|
| `yarn install --ignore-scripts` | `node_modules`も同時に生成される（lockfileのみの代替手段は存在しない） |

yarn v1には「lockfileだけを生成する」フラグがありません。Step 5でユーザー確認するとき、`node_modules`も生成される旨を明示してから承認を取ります。後始末として`node_modules`を消すかどうかも、ユーザーに委ねます。

## 4. ベースラインauditコマンドと抽出式

```bash
yarn audit --json 2>/dev/null \
  | jq -s 'map(select(.type=="auditSummary"))[0].data.vulnerabilities'
```

yarn v1の`yarn audit --json`はJSON-lines形式（1行1JSONオブジェクト）で出力されます。`jq -s`でストリームを配列にまとめてから、`.type=="auditSummary"`の行から`vulnerabilities`を取り出します。

出力形は以下の通りです。

```json
{"info":0,"low":0,"moderate":0,"high":0,"critical":0}
```

## 5. 観点1の対象パッケージadvisory抽出式

```bash
yarn audit --json \
  | jq -s '[.[] | select(.type=="auditAdvisory") | .data.advisory | select(.module_name=="<pkg>")]
           | unique_by(.id)
           | max_by(["info","low","moderate","high","critical"] | index(.severity))
           // {severity:"none"}'
```

yarn v1の`auditAdvisory`行は依存パスごとに同一の`.id`が重複して出るため、`unique_by(.id)`で重複を除いてから重大度の最大値を1つだけ取ります。観点1は「critical / highの有無」だけを見るので、件数ベースの判定ではなく「もっとも重いseverity」に畳む形で十分です。

対象パッケージのadvisoryが0件のとき`max_by`は空配列を受けて`null`を返します。0件は「該当なし＝GO」が意図なので、`// {severity:"none"}`で既定値を添えて挙動を固定します。判定側は`.severity`を引いて`"none"` / `"low"` / `"moderate"`をGO、`"high"`をHOLD、`"critical"`をNO-GOに振り分けます。

## 6. 観点5のpeer現状値取得方法

`yarn.lock`はYAML風の独自形式でjqでは扱えません。

```bash
# node_modulesがあればnpm lsで取得（yarn v1プロジェクトでもnpm lsは読めます）
if [ -d node_modules ]; then
  npm ls --json --depth=0 <peerDepName> 2>/dev/null \
    | jq -r '.dependencies["<peerDepName>"].version // empty'
fi
```

node_modulesがない場合は、現状peerが取れないものとしてHOLDに倒します。ユーザーに`yarn install`を促す案内文を添えます。

## 7. 設定取得方法（実効値）

yarn v1は環境固有で挙動が変わるため、本スキルでは設定の実効値取得は行わず、リポジトリ直下の`.yarnrc` / `.npmrc`の静的読みのみで進めます。

## 8. このパッケージマネージャー固有のエッジケース

### yarn v1のlockfile生成がnode_modulesも生成してしまう件

Section 3に記載した通り、`yarn install`はlockfileと同時に`node_modules`も生成します。Step 5でユーザー確認するとき、副作用を明示してから承認を取ります。

### `yarn audit`のJSON-lines形式

通常のJSONではなくJSON-linesです。`jq -s`でストリームを配列にまとめてから処理します。これを忘れて単純に`jq '.metadata...'`を流すと、複数オブジェクトをまたいだ操作で意図しない結果が出ます。

## 9. SKILL.mdからの参照箇所

| SKILL.mdのStep | このファイルの参照セクション |
|---|---|
| Step 2-2（設定実効値） | 7. 設定取得方法 |
| Step 3（installコマンド・audit準備） | 1, 2, 4 |
| Step 5（ベースライン取得） | 3, 4 |
| Step 6観点1（更新時CVE） | 5 |
| Step 6観点5（peer現状値） | 6 |
| エッジケース（lockfile生成） | 8 |
