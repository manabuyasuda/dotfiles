# グローバル指示

- YOU MUST: 日本語で応答する
- YOU MUST: 思い込みをせず事実を根拠に、明確な根拠を示して説明する
- IMPORTANT: コミットはプロジェクトの規約（commitlintや.gitmessage、AIエージェントのコミットSkills）に従う
  - 規約がない場合はConventional Commitsを使う

## 作業記録ディレクトリ

プロジェクトルートに作成する（bash-guard.shによりコミットを禁止されている）。

- `explore/` — 調査結果の一時キャッシュ（同じ探索の繰り返しを防ぎトークンを節約する）
- `plan/` — アプローチ・目的の検討と具体的な実装計画（標準のplan modeより優先する）
- `retrospective/` — セッションのふりかえり（最新ファイルに随時追記、なければ当日日付で作成）
  - Keep（随時）: ユーザー依頼の達成・うまくいった設定や判断
  - Problem（随時）: 手戻り・やり直し・暗黙のルールの見落とし
  - Try/Action: `/retrospective` スキルが追加してファイルに記録する

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
## スキルとエージェント

タスク着手前に該当スキルを確認する。

- `/code-review` — PR・ブランチのコードレビュー
- `/retrospective` — セッション終了時のKPTA
- `/hotspot-refactoring` — リファクタリング優先順位の決定
- `/rebasing-feature-branch` — フィーチャーブランチをベースブランチに追従
- `@digg` — 技術ドキュメント・調査結果の批判的検証
