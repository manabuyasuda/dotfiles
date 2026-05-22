# 動作検証ガイド: 判定ロジックの回帰検証

## このガイドが扱う範囲

判定ロジックの回帰検証を担当します。SKILL.mdおよび`package-managers/*.md`を変更したときに、観点1〜5の検証コマンド・抽出式・判定基準が壊れていないかを、代表パッケージで実機照合して確かめます。

防ぐ問題は、コマンド差分・抽出式・判定基準のいずれかが壊れたまま本番に出てしまい、ユーザーに誤ったGO / HOLD / NO-GO判定を渡してしまうことです。

## このガイドが扱わない検証範囲

以下は判定ロジックとは別の性質を持つため、本ガイドの対象外です。

| 検証種別 | 内容 | 現状の扱い |
|---|---|---|
| セキュリティ設計の動作 | scriptsが実行されない・node_modulesが作られない・tmpが削除される、といった隔離tmp＋多重防御フラグの実効確認 | 未着手です。将来は`security-design.md`として独立する予定です |
| 対話フローの動作 | socket未インストール時の3択、lockfile生成可否確認、マルウェア疑い受託時の中断などの`AskUserQuestion`挙動 | 未着手です。将来は`interactive-flows.md`として独立する予定です（手動チェックリスト形式） |
| エッジケースの動作 | パッケージ不在・指定バージョン不在・ネットワーク失敗・overrides上書き・モノレポなど、SKILL.md「エッジケースと例外」節の挙動 | 未着手です。将来は`edge-cases.md`として独立する予定です |

これらを実装する際は、本ファイルを`verifications/judgment-regression.md`に移動し、`verifications/`ディレクトリ配下に種別ごとのファイルを並べる構成に変更します。各ファイルは独立して走らせられる検証ガイドとし、`verifications/README.md`で「どの変更をしたら、どのファイルの検証を走らせるべきか」のマトリクスを集約する想定です。

## 前提

検証する前に、以下のコマンドが利用できることを確認します。

```bash
npm --version
jq --version
command -v socket && socket --version
```

`socket`がインストールされていない場合は`npm install -g @socketsecurity/cli`でインストールします。

## 検証ケース（初版）

| 番号 | パッケージ | 期待判定 | 効く観点 | 期待シグナル |
|---|---|---|---|---|
| 1 | `lodash@4.17.21` | HOLD | 観点1（high） | `npm audit`でhigh 1件、MIT、deprecatedなし、peerDependenciesなし |
| 2 | `lodash@4.17.10` | NO-GO | 観点1（critical） | `npm audit`でcritical 1件、MIT、deprecatedなし、peerDependenciesなし |
| 3 | `request@2.88.2` | NO-GO | 観点1（critical支配）・観点3（deprecated） | `npm audit`でcritical 2件＋moderate 3件、Apache-2.0、deprecatedフィールドあり |

各ケースとも、観点2のsocketスキャンは「`found no risks`」を期待します。

ケース3は「複数観点が同時にHOLD/NO-GO相当の場合、もっとも厳しい結果が総合判定を支配する」という仕様も同時に確認します。観点3のdeprecatedだけでなく観点1のcriticalがあるため、総合はNO-GOになります。

## 実行手順

各ケースは「隔離tmpを作る → socket npm install → npm audit → npm view → 期待値と突き合わせ」の流れです。SKILL.md Step 6冒頭のセットアップ手順に従います。検証では`trap`が効くよう、スクリプト全体を1つの`bash`プロセスで走らせてください。インタラクティブシェルで分けて叩くと`trap`が発火せず、tmpディレクトリが残ったままになります。

### ケース1: lodash@4.17.21

```bash
bash <<'EOF'
WORK=$(mktemp -d "${TMPDIR:-/tmp}/socket-verify-XXXXXX")
mkdir -p "$WORK/.npm-cache"
case "$WORK" in
  */socket-verify-*) ;;
  *) echo "unexpected WORK=$WORK"; exit 1 ;;
esac
trap 'rm -rf "$WORK"' EXIT

( cd "$WORK" && socket npm install \
    --package-lock-only \
    --ignore-scripts \
    --cache="$WORK/.npm-cache" \
    lodash@4.17.21 ) 2>&1 \
  | tee "$WORK/socket-output.txt" > /dev/null

echo "===socket出力（最後の数行に found no risks があれば成功）==="
grep -iE 'found (no )?risks' "$WORK/socket-output.txt" || echo "（risks言及なし）"

echo "===観点1: npm audit==="
( cd "$WORK" && npm audit --json 2>/dev/null ) \
  | jq '{summary: .metadata.vulnerabilities, target: .vulnerabilities["lodash"] | {name, severity}}'

echo "===観点3-5: npm view==="
npm view lodash@4.17.21 --json 2>/dev/null \
  | jq '{license, time_modified: .time.modified, maintainers_count: (.maintainers | length), repository_url: .repository.url, deprecated, peerDependencies}'
EOF
```

期待出力は以下の通りです。

- socket出力に`found no risks`
- `npm audit`のsummaryに`"high": 1`、targetの`severity`が`"high"`
- `license`が`"MIT"`、`deprecated`が`null`、`peerDependencies`が`null`

### ケース2: lodash@4.17.10

ケース1の`bash <<'EOF' ... EOF`ブロックを以下に差し替えて実行します（パッケージ名のみ変更）。

```bash
# 「socket npm install」と「npm view」の引数を以下に変更します
lodash@4.17.10
```

期待出力は以下の通りです。

- socket出力に`found no risks`
- `npm audit`のsummaryに`"critical": 1`、targetの`severity`が`"critical"`
- `license`が`"MIT"`、`deprecated`が`null`

### ケース3: request@2.88.2

同様にケース1のブロックでパッケージ名を`request@2.88.2`に差し替え、`.vulnerabilities["lodash"]`の`lodash`を`request`に変更して実行します。

期待出力は以下の通りです。

- socket出力に`found no risks`
- `npm audit`のsummaryに`"critical": 2, "moderate": 3`程度（advisoryは時間とともに追加されます）、targetの`severity`が`"critical"`
- `license`が`"Apache-2.0"`、`deprecated`に"deprecated"を含む文字列、`peerDependencies`が`null`

## 確認ポイント

各ケース実行後、以下を上から順に照合します。1つでも不一致なら、変更したファイルのどこで判定基準・抽出式・コマンドが壊れたかを切り分けてください。

| 観点 | 確認すること | 不一致時の調査先 |
|---|---|---|
| 観点1（CVE） | `npm audit`の出力JSONに対象パッケージのadvisoryが含まれ、severityが期待値と一致する | `package-managers/npm.md`の「5. 観点1の対象パッケージadvisory抽出式」、SKILL.md Step 6 観点1 |
| 観点2（サプライチェーン） | socket-output.txtに`found no risks`か`found risks ...`の文字列がある | SKILL.md Step 6 観点2の判定表、socket CLIバージョン |
| 観点3（メンテナンス） | `npm view`出力に`time_modified`／`maintainers_count`／`repository_url`／`deprecated`のすべてが含まれる | SKILL.md Step 6 観点3のjq抽出式 |
| 観点4（ライセンス） | `license`フィールドが期待値と一致する | SKILL.md Step 6 観点4の判定表 |
| 観点5（peerDeps） | `peerDependencies`フィールドが含まれる（観点3のjqで一緒に取得） | SKILL.md Step 6 観点3のjq抽出式に`peerDependencies`が含まれているか |
| 総合判定 | もっとも厳しい観点が総合判定を支配する（ケース3で確認） | SKILL.md Step 7の「総合判定」 |

## 将来追加するケース候補

初版の3ケースは観点1・観点3を中心にカバーしています。スキル変更でその他の観点を触った場合は、以下のケースを追加して回帰を検出すると安全です。いずれもまだ実行していないため、実行前に期待値の妥当性を確認してください。

| ケース候補 | 期待判定 | 効く観点 | 確認したいこと | 状態 |
|---|---|---|---|---|
| 健全な現行版（例: `axios@latest`等） | GO | 全観点クリア | 5観点すべてがGOになるケースの存在 | 未走行 |
| `node-forge@latest`（`(BSD-3-Clause OR GPL-2.0)`） | GO | 観点4 SPDX OR | `OR`式で片方が許容リストに含まれていればGOになる | 未走行 |
| `tweetnacl@latest`（`Unlicense`） | GO | 観点4 | `Unlicense`（SPDX識別子）が`UNLICENSED`（npm独自マーカー）と混同されずGOになる | 未走行 |
| 意図的に作ったpeer不整合プロジェクト | HOLD | 観点5 | peerDeps判定 + `legacy-peer-deps=true`の組み合わせで「installは成功するが…」のHOLD分岐に入る | 未走行 |

## 既知の制約

ここで走らせる検証では、以下は構造的に確認できません。

### 観点2の`found risks`分岐

安全に検証用に使えるknown-bad（マルウェア）パッケージが手に入らないため、`socket npm install`で`found risks`が出るケースは検証できません。`found no risks`ブランチのみが検証範囲です。socketの出力形が変わった場合は、別途socket CLIのドキュメントやリリースノートで確認してください。

### 同名異版パッケージの同時検証

`lodash@4.17.21`と`lodash@4.17.10`を1つのtmpに同居させると、npmの依存解決でどちらか一方しかlockfileに入りません。同名異版を比較したい場合は、必ず別tmpディレクトリで走らせます。

### 観点1の経路1（プロジェクトのaudit）

検証は隔離tmpの「経路2」のみで実行しています。プロジェクト側のauditを使う経路1は、実プロジェクトで動作するため検証ガイドからは外しています。`package-managers/*.md`の「5. 観点1の対象パッケージadvisory抽出式」を変更した場合は、対応するパッケージマネージャーのプロジェクトで個別に動作確認してください。

### bun

スキル本体ではbunを対象に含めていません。bunプロジェクトでスキルを動かしたい場合は、別途参照ファイルの追加と検証ケースの拡張が必要です。

## クリーンアップ

`bash <<'EOF' ... EOF`でスクリプト全体を1つのプロセスとして走らせれば`trap`がtmpを自動削除します。インタラクティブシェルで分けて叩いた場合は以下で手動削除してください。

```bash
ls -d "${TMPDIR:-/tmp}"/socket-verify-* 2>/dev/null
rm -rf "${TMPDIR:-/tmp}"/socket-verify-*
```

削除前に`ls`で対象を目視確認することを推奨します。
