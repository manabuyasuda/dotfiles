# yarn v2+ (Berry)参照ファイル

`SKILL.md`から参照されます。運用ルール（参照タイミング・正常系での独自考案禁止・問題発生時の自律対応）は`SKILL.md`の「パッケージマネージャー固有の操作は外部ファイル参照（必須ルール）」セクションに集約しています。

## 1. 検出ソース

- リポジトリルートに`yarn.lock`と`.yarnrc.yml`の両方が存在する場合
- または`package.json`の`packageManager`フィールドが`"yarn@2.*"` / `"yarn@3.*"` / `"yarn@4.*"`で始まる場合
- または`yarn --version`の出力が`2.*` / `3.*` / `4.*`の場合

## 2. 推奨install / updateコマンド

| 操作 | コマンド |
|---|---|
| 通常追加 | `yarn add <pkg>@<version>` |
| devDependency追加 | `yarn add <pkg>@<version> --dev` |
| 更新 | `yarn up <pkg>@<version>` |

## 3. lockfile生成コマンドと副作用

| コマンド | 副作用 |
|---|---|
| `yarn install --mode=update-lockfile` | `yarn.lock`のみ更新、`node_modules`は作らない |

## 4. ベースラインauditコマンドと抽出式

```bash
yarn npm audit --recursive --json 2>/dev/null \
  | jq -s '[.. | objects | (.severity // .Severity) | select(. != null)]
           | group_by(.)
           | map({key:.[0], value:length})
           | from_entries'
```

`yarn npm audit --json`は版で形が揺れます。

- 4.0.1未満は単一JSONで小文字`severity`を使います
- 4.0.1以降はNDJSONで`children`配下の大文字`Severity`を使います

抽出式は両形式を吸収するため`(.severity // .Severity)`を使い、`jq -s`でストリームをまとめて受けます。yarn 4.5.0の実機検証では、`{"value":"<pkg>","children":{"ID":...,"Severity":"<level>",...}}`の形を`{critical,high,moderate,low}`に正規化できることを確認しました。

それでも抽出が空になる版を踏んだ場合は「baseline取得失敗」として続行し、判定表に「yarn berry audit抽出失敗」と明示します。観点1のフォールバック経路（SKILL.md Step 6.1）が発動します。

## 5. 観点1の対象パッケージadvisory抽出式

```bash
yarn npm audit --recursive --json \
  | jq -s '[.. | objects
           | select((.module_name // .value)=="<pkg>")
           | {severity:(.severity // .Severity // .children.Severity)}]'
```

yarn berry 4.5.0で実機検証済みです（lodash@4.17.10で9件のadvisoryを正しく取得できることを確認しました）。

判定側は配列要素の`.severity`を集計し、含まれる中でもっとも重いseverityを採用します。`"critical"`があればcritical、無くて`"high"`があればhigh、それ以外はmoderate以下扱いです。

抽出結果が空配列になる場合は、yarn berryの版揺れが疑われます。SKILL.md Step 6.1のフォールバック経路で隔離tmpの`npm audit`に倒します。

## 6. 観点5のpeer現状値取得方法

`yarn.lock`（v2以降の形式）はYAML風でjqでは扱えません。

```bash
# node_modulesがあればnpm lsで取得
if [ -d node_modules ]; then
  npm ls --json --depth=0 <peerDepName> 2>/dev/null \
    | jq -r '.dependencies["<peerDepName>"].version // empty'
fi
```

yarn berryの`nodeLinker`設定によっては`node_modules`を作らない構成（Plug'n'Play）の場合があります。その場合は`npm ls`が動かないため、現状peerが取れないものとしてHOLDに倒し、ユーザーに`yarn install`かyarn固有の手段での確認を促します。

## 7. 設定取得方法（実効値）

```bash
yarn config get <key>
```

`yarn config get`は実効値を返しますが、`--location`相当の引数を提供しないため、取得元の判別はできません。スナップショットには「実効値のみ」を記録し、取得元は「不明（実効値のみ）」と明示します。

判定に使うキーは`nodeLinker`、`packageExtensions`です。

`.yarnrc.yml`の静的読みもStep 2-1で行います。

## 8. このパッケージマネージャー固有のエッジケース

### audit JSON形式が異なるバージョン

Section 4に記載した通り、yarn berryは版によって`yarn npm audit --json`の出力形が変わります。Section 4の抽出式は「severity / Severity両方を`..`で拾ってgroup_by」する保守的な形にしてあるため、形式変化にある程度耐えます。ただし抽出結果が空になった場合は「baseline取得失敗」として続行し、観点1はフォールバック経路（隔離tmpの`npm audit`）を使います。

### Plug'n'Play (PnP)構成でのnode_modules不在

`.yarnrc.yml`の`nodeLinker: pnp`（または未指定でberryのデフォルト）の場合、`node_modules`が存在しません。peer現状値取得は`npm ls`経由ではできず、HOLDに倒します。

## 9. SKILL.mdからの参照箇所

| SKILL.mdのStep | このファイルの参照セクション |
|---|---|
| Step 2-2（設定実効値） | 7. 設定取得方法 |
| Step 3（installコマンド・audit準備） | 1, 2, 4 |
| Step 5（ベースライン取得） | 3, 4 |
| Step 6観点1（更新時CVE） | 5 |
| Step 6観点5（peer現状値） | 6 |
| エッジケース（audit版揺れ・PnP） | 8 |
