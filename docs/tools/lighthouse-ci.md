# Lighthouse CI

Google LighthouseをCI/CDパイプラインで自動実行するツール。パフォーマンス、アクセシビリティ、ベストプラクティス、SEOのスコアを継続的に監視できる。

## インストール

```bash
npm install -g @lhci/cli
```

`nodenv/default-packages`で自動インストールされる。

## 基本的な使い方

```bash
# 設定ファイルを初期化
lhci wizard

# Lighthouseを実行して結果を収集
lhci collect --url https://example.com

# アサーションを実行（スコアが閾値を下回ると失敗）
lhci assert

# 結果をアップロード（LHCI Serverまたは一時ストレージ）
lhci upload --target=temporary-public-storage

# 収集からアップロードまで一括実行
lhci autorun
```

## 主要コマンド

| コマンド | 説明 |
| --- | --- |
| `lhci collect` | Lighthouseを実行し、結果をローカルフォルダに保存する |
| `lhci upload` | 収集した結果をサーバーにアップロードする |
| `lhci assert` | 最新の結果が期待値を満たしているか検証する |
| `lhci autorun` | collect/assert/uploadを適切なデフォルト設定で一括実行する |
| `lhci healthcheck` | 設定が正しいか診断を実行する |
| `lhci open` | 収集した結果のHTMLレポートをブラウザで開く |
| `lhci wizard` | CI設定のステップバイステップウィザードを起動する |
| `lhci server` | Lighthouse CIサーバーを起動する |

## グローバルオプション

| オプション | 説明 |
| --- | --- |
| `--help` | ヘルプを表示する |
| `--version` | バージョンを表示する |
| `--no-lighthouserc` | `.lighthouserc`ファイルの自動読み込みを無効にする |
| `--config` | JSON設定ファイルのパスを指定する |

## ユースケース

### CIでパフォーマンススコアの低下を検知する

`lighthouserc.json`:

```json
{
  "ci": {
    "collect": {
      "url": ["http://localhost:3000/", "http://localhost:3000/about"]
    },
    "assert": {
      "assertions": {
        "categories:performance": ["error", { "minScore": 0.9 }],
        "categories:accessibility": ["error", { "minScore": 0.9 }]
      }
    }
  }
}
```

```bash
lhci autorun
```

### 複数ページのスコアを一括チェックする

```bash
lhci collect --url https://example.com/ --url https://example.com/about --url https://example.com/contact
lhci assert
```

### PRごとにパフォーマンスレポートを生成する

```bash
lhci autorun --upload.target=temporary-public-storage
```

一時的な公開ストレージにアップロードし、PRのコメントにリンクを貼ることでレビューに活用する。

### ローカルでHTMLレポートを確認する

```bash
lhci collect --url https://example.com
lhci open
```

`collect`で収集した結果をHTMLレポートとしてブラウザで開く。CIにアップロードせずに手元で結果を確認したい場合に便利。

### 設定の問題をデバッグする

```bash
lhci healthcheck
```

Chromeのインストール状況や設定ファイルの妥当性を診断する。CIで原因不明のエラーが発生した際のトラブルシューティングに使う。

### lighthousercで設定を管理する

プロジェクトルートに`.lighthouserc.json`（または`.lighthouserc.yml`/`.lighthouserc.js`）を配置すると、コマンド実行時に自動で読み込まれる。

```json
{
  "ci": {
    "collect": {
      "url": ["http://localhost:3000/"],
      "numberOfRuns": 3
    },
    "assert": {
      "assertions": {
        "categories:performance": ["error", { "minScore": 0.8 }],
        "categories:accessibility": ["warn", { "minScore": 0.9 }],
        "categories:best-practices": ["warn", { "minScore": 0.9 }]
      }
    },
    "upload": {
      "target": "temporary-public-storage"
    }
  }
}
```

`--no-lighthouserc`オプションで自動読み込みを無効にし、`--config`オプションで別のファイルを指定することもできる。

## 参考リンク

- [GitHub - Lighthouse CI](https://github.com/GoogleChrome/lighthouse-ci)
- [npm - @lhci/cli](https://www.npmjs.com/package/@lhci/cli)
- [Lighthouse CI ドキュメント](https://github.com/GoogleChrome/lighthouse-ci/blob/main/docs/getting-started.md)
