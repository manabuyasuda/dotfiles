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
## 使用可能なスキル

`/スキル名` で呼び出す。

| スキル | 使う場面 |
|---|---|
| `code-review` | PRまたはローカルブランチのコードをレビューするとき |
| `hotspot-refactoring` | リファクタリング対象の優先順位を決めたいとき（git log・循環参照・不安定性メトリクスを分析） |
| `pr-dashboard` | 自分のPR・レビュー依頼・GitHub通知をまとめて確認したいとき |
| `rebasing-feature-branch` | フィーチャーブランチをベースブランチ（main等）に追従させるとき |
| `retrospective` | セッション終了時にKPTAふりかえりを実施し`retrospective/`に記録するとき |
| `web-design-guidelines` | UIのアクセシビリティ・UX・デザインをWeb Interface Guidelinesに基づいてレビューするとき |
| `vercel-react-best-practices` | React/Next.jsのコンポーネント・データフェッチ・バンドル最適化をレビュー・実装するとき |
| `vercel-composition-patterns` | boolean propが増えたコンポーネントを整理したい・再利用可能なAPIを設計するとき |

## 使用可能なエージェント

`@エージェント名` で呼び出す。

| エージェント | 使うとき |
|---|---|
| `@digg` | 技術ドキュメント・調査結果が実装着手できる状態か批判的に検証したいとき。不足している観点を質問リストとして返す |
