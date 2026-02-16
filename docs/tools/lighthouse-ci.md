# Lighthouse CI

Google Lighthouse を CI/CD パイプラインで自動実行するツール。パフォーマンス、アクセシビリティ、ベストプラクティス、SEO のスコアを継続的に監視できる。

## インストール

```bash
npm install -g @lhci/cli
```

`nodenv/default-packages` で自動インストールされる。

## 基本的な使い方

```bash
# 設定ファイルを初期化
lhci wizard

# Lighthouse を実行して結果を収集
lhci collect --url https://example.com

# アサーションを実行（スコアが閾値を下回ると失敗）
lhci assert

# 結果をアップロード（LHCI Server または一時ストレージ）
lhci upload --target=temporary-public-storage

# 収集からアップロードまで一括実行
lhci autorun
```

## ユースケース

### CI でパフォーマンススコアの低下を検知する

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

### PR ごとにパフォーマンスレポートを生成する

```bash
lhci autorun --upload.target=temporary-public-storage
```

一時的な公開ストレージにアップロードし、PR のコメントにリンクを貼ることでレビューに活用する。

## 参考リンク

- [GitHub - Lighthouse CI](https://github.com/GoogleChrome/lighthouse-ci)
- [npm - @lhci/cli](https://www.npmjs.com/package/@lhci/cli)
- [Lighthouse CI ドキュメント](https://github.com/GoogleChrome/lighthouse-ci/blob/main/docs/getting-started.md)
