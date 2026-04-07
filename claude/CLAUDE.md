# グローバル指示

- YOU MUST: 日本語で応答する
- YOU MUST: 思い込みをせず事実を根拠に、明確な根拠を示して説明する
- IMPORTANT: コミットはプロジェクトの規約（commitlintや.gitmessage、AIエージェントのコミットSkills）に従う
  - 規約がない場合はConventional Commitsを使う
- IMPORTANT: ドキュメントには信頼性のある情報のリンクと引用を積極的に記載する
```
＜英語の引用＞
＜日本語訳（日本語を引用する場合は省略）＞
＜[引用した情報のタイトル](URL)＞
```

## 作業記録ディレクトリ

プロジェクトルートに作成する（bash-guard.shによりコミットを禁止されている）。

- `explore/` — 調査・依存関係・影響範囲の記録
- `plan/` — 実装計画・手順
- `retrospective/` — セッションのふりかえりと改善

## 使用可能なCLIツール

各ツールの詳細は `~/Documents/MY/dotfiles/docs/tools/` を参照する。

### GitHub / Git
- `gh`: PR作成・issue操作・通知確認などのGitHub操作全般
  - `gh dash`: PR・issueのダッシュボード
  - `gh notify` / `gh f`: GitHub通知の確認・フィルタリング
  - `gh s`: リポジトリ横断のコード検索
  - `gh poi`: マージ済みローカルブランチの一括削除
  - `gh clean-branches`: 不要ブランチのクリーンアップ

### 依存関係分析（JS/TS）
- `madge`: 循環参照検出（`--circular`）・逆依存調査（`--depends`）・依存サマリー（`--summary`）
- `depcruise`: 安定度メトリクス（`--metrics`）・影響範囲可視化（`--affected`）・アーキテクチャ制約検証
- `knip`: 未使用ファイル・エクスポート・依存の検出

### コード品質
- `type-coverage`: TypeScriptの型カバレッジ計測
- `semgrep`: セキュリティ脆弱性・パターンベースの静的解析
- `socket`: npmパッケージのサプライチェーンリスク検出

### パフォーマンス・アクセシビリティ
- `lhci`: パフォーマンス・アクセシビリティ・SEOの継続スコア計測
- `bundle-phobia`: npmパッケージのバンドルサイズ確認
- `axe`: WCAG基準のアクセシビリティ違反検出
- `ncu`: npm依存パッケージの更新確認