# sfw（Socket Firewall）

パッケージマネージャーの通信を仲介して、不審なパッケージのインストールをリアルタイムにブロックするローカルプロキシ。npm・pnpm・yarn・pip・uv・cargoなどをラップして使う。Socketの脅威データベースを参照し、悪意あるパッケージへのfetchを未然に遮断する。

## インストール

```bash
mise use -g npm:sfw
```

Node.jsのバージョンを切り替えてもグローバルインストールが保持される。

直接npmでも導入できる。

```bash
npm install -g sfw
```

`sfw` という名前のnpmパッケージ自体はインストーラー/ランチャーで、実体のSocket Firewallは実行時に取得される。

## 基本的な使い方

任意のパッケージマネージャーコマンドを `sfw` でラップして実行する。

```bash
sfw npm install
sfw pnpm add lodash
sfw pip install requests
sfw cargo add serde
```

`~/.zshrc` でエイリアスを張ると、普段使いのコマンドが透過的にラップされる。

```bash
alias npm="sfw npm"
alias npx="sfw npx"
alias yarn="sfw yarn"
alias pnpm="sfw pnpm"
alias pip="sfw pip"
alias uv="sfw uv"
alias cargo="sfw cargo"
```

Bunは未対応。

## 主要オプション

| オプション | 説明 |
| --- | --- |
| `--verbose` | バナーや検査済みパッケージ数などの診断出力を表示する |
| `--help` | ヘルプを表示する |

環境変数 `SFW_VERBOSE=true` でも `--verbose` と同じ効果が得られる。

## 動作確認

```bash
SFW_VERBOSE=true npm -v
```

次のように `Protected by Socket Firewall` が表示されれば、エイリアス経由でsfwが起動している。

```
Protected by Socket Firewall
11.13.0
```

デフォルトではsfwはバナーを出さないため、確認時は必ず `SFW_VERBOSE=true` か `--verbose` を付ける。`sfw --verbose npm -v` でもsfw自体の動作は確認できるが、`alias npm="sfw npm"` の設定漏れには気付けないため、エイリアス経由の `SFW_VERBOSE=true npm -v` が適切。

## ユースケース

### グローバルインストール時のサプライチェーン攻撃を防ぐ

```bash
SFW_VERBOSE=true npm install -g some-package
```

`npm install -g` や `npx` を通じた悪意あるパッケージの混入を、ネットワーク層で遮断する。`min-release-age`（npm）や `minimumReleaseAge`（pnpm）と組み合わせると、公開直後の悪意あるバージョンの取得も併せて抑止できる。

### CI でサプライチェーンを継続監視する

```bash
SFW_VERBOSE=true sfw npm ci
```

CIのインストール工程で `sfw` を挟むことで、依存関係の取得をSocketの脅威データベース照合付きで実行できる。`--verbose` で検査済みパッケージ数をログに残すと、後追いの監査がしやすい。

## Socket との関係

[Socket](socket.md) はパッケージのスコア取得・スキャン・CVE修正など包括的にサプライチェーンを分析するツールで、`socket wrapper --enable` でnpm/npxのラッパーも提供する。一方sfwは「ネットワーク層でfetchをブロックする」という用途に特化した軽量プロキシで、Bunを除く主要パッケージマネージャーを単一のコマンドでラップできる。導入の手軽さとカバー範囲を重視する場合はsfw、より深いセキュリティ分析やレポートが必要な場合はSocketを使う。併用も可能。

## 参考リンク

- [Socket Firewall 公式ドキュメント](https://docs.socket.dev/docs/socket-firewall)
- [GitHub - SocketDev/sfw-installer](https://github.com/SocketDev/sfw-installer)
- [npm - sfw](https://www.npmjs.com/package/sfw)
