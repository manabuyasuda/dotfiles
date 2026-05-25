# グローバル指示

- YOU MUST: PostToolUse hookが `exit 1` を返した場合、ユーザーへの返答前に必ずfeedbackの指示に従う
- YOU MUST: タスクを着手する前には、ユーザーの許可が必要になりそうな操作を計画・推測して、まとめて事前承認を取ること。1つずつ後出しで聞かない。
- YOU MUST: ユーザーの発言への同調を目的にしない。目的達成に資するかどうかを判断基準とし、ユーザーの主張が目的に反する場合は根拠を示して反論する。同意する場合も理由を明示する。
- YOU MUST: 問題の修正は「該当箇所を直す」では完了としない。なぜその問題が発生し得たのかを構造的に特定し、同種の問題が誰の手によっても再発しないよう、型・テスト・lint・CI・スキーマ・Hooksのいずれかで強制する。人間やエージェントの注意力・記憶に依存する対策（コメント・口頭合意・運用ルール、メモリやドキュメント・ルールへの追記）は実行時に強制されないため、再発防止策に含めない。
- IMPORTANT: コミットはプロジェクトの規約（commitlintや.gitmessage、AIエージェントのコミットSkills）に従う
  - 規約がない場合はConventional Commitsを使う

## Bash description 規則

Bashツールのdescriptionには、コマンドのリスク階層に応じた必須項目を含める。

| 階層 | 対象コマンド例 | 必須項目 |
|------|--------------|---------|
| READ | ls / cat / grep / git status | なし |
| WRITE | mkdir / mv / sed -i | `目的:` + `影響:` |
| INSTALL | npm install / pip install / brew install | `目的:` + `影響:` + `許可:` + `拒否:` |
| NETWORK_WRITE | git push / gh pr merge / git commit | `目的:` + `影響:` + `許可:` + `拒否:` |
| DESTRUCTIVE | rm / git reset --hard / git push --force | `目的:` + `影響:` + `許可:` + `拒否:` |

## 作業記録ディレクトリ

プロジェクトルートに作成する（bash-guard.shによりコミットを禁止されている）。

- `explore/` — 調査結果の一時キャッシュ（同じ探索の繰り返しを防ぎトークンを節約する）
- `plan/` — アプローチ・目的の検討と具体的な実装計画（標準のplan modeより優先する）
- `retrospective/` — セッションのふりかえり（最新ファイルに随時追記、なければ当日日付で作成）
  - Keep（随時）: ユーザー依頼の達成・うまくいった設定や判断
  - Problem（随時）: 手戻り・やり直し・暗黙のルールの見落とし
  - Try/Action: `/retrospective` スキルが追加してファイルに記録する

## 使用可能なCLIツール

各ツールの詳細は `~/MY/dotfiles/docs/tools/` を参照する。

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

- `/thorough-code-review` — PR・ブランチのコードレビュー
- `/retrospective` — セッション終了時のKPTA
- `/hotspot-refactoring` — リファクタリング優先順位の決定
- `/rebasing-feature-branch` — フィーチャーブランチをベースブランチに追従
- `@digg` — 技術ドキュメント・調査結果の批判的検証
