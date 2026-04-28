# 検証方法（Verification Methods）

「テスト = テストコードを書く」ではありません。検証は3層で考えます。
ユースケースから検証手段を割り当てるとき、自動テストだけでなくAgentic Verification（エージェント駆動検証）と手動検証も選択肢に含めます。

## 1. 検証の3層

| 層 | 主な目的 | 実行頻度 | 主な担い手 |
|---|---|---|---|
| 自動テスト | 退行検知 | CIで常時 | テストランナー |
| Agentic Verification | 仕様確定 / 不具合再現 / 実環境の実値確認 | 開発中・必要時 | Claude Code等のエージェント |
| 手動検証 | UX判断 / 新規体験の評価 / 最終受け入れ | リリース前 | 人間 |

3つは排他ではなく補完関係です。Agentic Verificationで確認したことを必要に応じて自動テストに昇格させる流れが自然です。

## 2. 自動テスト

既存の系統別 reference に列挙しているもの。退行検知のため CI で繰り返し実行する。

- 系統E: e2e / visual regression / a11y自動チェック / component test
- 系統D: unit / 型テスト / contract / build smoke / bundle size assertion
- 系統O: integration / 管理画面e2e / 権限境界テスト / 監査ログ検証

高頻度で回せるため、失敗を即座に検出できます。一方、書くコストが高く、実環境固有の挙動（CDN、実ブラウザ、CSSの実適用値）は拾いきれないことが多い点に注意が必要です。

## 3. Agentic Verification

エージェント（Claude Code等）が実環境で直接検証する手段です。テストコードを書かずに、その場で確認します。

### 3.1 主な手段

#### (a) ブラウザ操作 MCP

Chrome DevTools MCPまたはPlaywright MCPを使い、ページを開く、要素をクリック、フォーム入力、スクショ取得、コンソールログ取得、ネットワーク監視、Performance計測、a11y tree取得を行います。

用途は以下の通りです。

- 系統E: 実際にUI操作して、画面遷移と表示を確認
- 系統E: フォーカス順序、タブキー移動の実確認
- 系統E: コンソールエラー / 警告の検出
- 系統O: ステージング環境で管理画面の操作確認

#### (b) JSでの実値取得（ブラウザコンテキスト内で評価）

ブラウザMCP経由で `evaluate` / `runtime.evaluate` 系を使い、実際の値を取得します。

```js
// 適用されているCSSの実値
const cs = getComputedStyle(el);
cs.fontFamily; cs.color; cs.gridTemplateColumns;

// 実際のレイアウト
el.getBoundingClientRect();

// Performance metrics（LCP, CLS, INP）
performance.getEntriesByType('largest-contentful-paint');
performance.getEntriesByType('layout-shift');

// アクセシビリティ
el.getAttribute('aria-label');
document.activeElement;

// エラー検出
window.addEventListener('error', e => /* ... */);
window.addEventListener('unhandledrejection', e => /* ... */);

// バンドル情報
performance.getEntriesByType('resource')
  .filter(r => r.name.endsWith('.js'))
  .map(r => ({ url: r.name, transferSize: r.transferSize }));
```

用途は以下の通りです。

- 系統E: 「CSSが意図通り適用されているか」を実値で確認（visual regressionより直接的）
- 系統E: CLS / LCP / INPの実測
- 系統D: SSRハイドレーション後のDOM構造確認、コンソールエラーの拾い上げ
- 系統D: 実バンドルでどのコードが含まれているか確認

#### (c) コード実行（Claude Code ネイティブ）

ファイルを書く / コマンドを実行する標準ツールで完結する検証手段です。

- ビルド成果物の直接検査（`dist/` を grep する、AST で確認する）
- 実際にミニサンプルを書いてバンドルし、tree-shaking の結果を確認
- TypeScript の `tsc --noEmit` を実行して型エラーを確認
- API を curl で叩いてレスポンスを直接確認

用途は以下の通りです。

- 系統D: tree-shaking の実証（`@rollup/plugin-visualizer` 等の出力を読む）
- 系統D: 公開シグネチャを使った最小サンプルが実際にビルドできるか
- 系統D: ESM / CJS 両方からの import 動作確認

#### (d) 連携先 MCP

データベース MCP / GitHub MCP / Slack MCP 等を使い、副作用の発生先を直接確認します。

用途は以下の通りです。

- 系統O: DB の状態変化を実SQL で確認
- 系統O: 監査ログテーブルの実レコード検査

### 3.2 強みと弱み

強みは以下の通りです。

- テストコードを書く前に「動く・動かない」「実値はこうなっている」を即確認できます
- 実環境固有の挙動（実ブラウザ、実CDN、実APIレスポンス）を直接見られます
- 仕様確定段階で、書くべき自動テストの輪郭を明確化できます

弱みは以下の通りです。

- 再現性が低いため、次回同じ確認をするには再度エージェントを動かす必要があります
- 退行検知に弱く、毎回確認しないと壊れたことに気づけません
- 環境依存のため、ローカル / ステージング / 本番で結果が変わります

### 3.3 自動テストへの昇格基準

Agentic Verificationで見つけたものは、以下に当てはまれば自動テストに昇格させます。

- [ ] 一度直しても再発する可能性がある
- [ ] 退行したら影響が大きい
- [ ] アサーションが安定して書ける（揺れの少ない期待値が定義できる）
- [ ] 実行コストが妥当（e2e で5分以上かかるなら整理する）

逆に、以下は自動テストにせずAgentic Verificationのまま残してかまいません。

- 一度きりの仕様確認
- 探索的な不具合調査
- アサーションが揺れやすい（UX的判断、複雑なレイアウト）
- 実環境でしか再現しない（CDN設定の確認等）

## 4. 手動検証

人間の目視・操作で確認します。Agentic Verificationでも代替できないものを残します。

- UX判断（「使いやすいか」「直感的か」）
- 新規体験の最終評価
- 微細なアニメーション・トランジションの自然さ
- アクセシビリティ実機確認（実スクリーンリーダー、実支援技術）
- 多言語の意味ニュアンス確認

## 5. ユースケースから検証方法への割り当て

各UCの「適用される観点」に対し、3層のどれで検証するかを割り当てます。1観点に複数層を割り当ててかまいません（例: 自動テストで退行検知 + Agenticで実値確認）。

### 系統E の典型パターン

| 観点 | 自動テスト | Agentic Verification | 手動 |
|---|---|---|---|
| 主要ジャーニー | e2e | Playwright MCP で実操作 | リリース前確認 |
| 入力バリエーション | component test | — | — |
| エラーリカバリの表示 | component test + visual | ブラウザMCPでエラー発火させて画面確認 | — |
| アクセシビリティ | axe 自動チェック | Chrome DevTools MCP で a11y tree 取得、フォーカス順序確認 | 実スクリーンリーダー |
| CSS適用値 | visual regression | `getComputedStyle()` で実値取得 | — |
| CLS / LCP | Lighthouse CI | `performance.getEntries*()` で実測 | — |
| デバイス多様性 | visual (複数 viewport) | ブラウザMCPで viewport 切替 | 実機確認 |

### 系統D の典型パターン

| 観点 | 自動テスト | Agentic Verification | 手動 |
|---|---|---|---|
| 公開API契約（runtime） | unit | 最小サンプル書いて実行 | — |
| 公開API契約（型） | tsd / expect-type | `tsc --noEmit` で実エラー確認 | — |
| Tree Shaking | bundle size assertion | 実バンドル成果物を grep / AST で検査 | — |
| ESM/CJS 互換 | build smoke | 実プロジェクトで import して動作確認 | — |
| SSR `window` ガード | unit (jsdom + node 両方) | Next.js 実プロジェクトで SSR 実行、コンソールエラー確認 | — |

### 系統O の典型パターン

| 観点 | 自動テスト | Agentic Verification | 手動 |
|---|---|---|---|
| 権限境界 | 権限境界テスト | ステージングで各ロールでログインして実確認 | — |
| 監査ログ | integration | DB MCP で `audit_logs` テーブル直接検査 | — |
| 影響範囲プレビュー | 管理画面 e2e | ブラウザMCPでドライラン実行して結果確認 | — |
| キャッシュ無効化 | integration | 実 CDN へのリクエストヘッダ確認、ブラウザMCPで再取得 | — |

## 6. 落とし穴

| 落とし穴 | 対処 |
|---|---|
| Agentic Verificationを「テスト書かなくていい言い訳」にする | 退行検知が必要なものは自動テストに昇格させます。Agenticは仕様確定 / 探索が本領です。 |
| 本番環境でAgentic Verificationを回す | 副作用のある操作（特に系統O）は必ずステージングで実行します。本番でやる場合はread-onlyに限定します。 |
| MCPの設定差で結果がブレる | ブラウザMCPのバージョン、ヘッドレス/有頭、viewport設定で結果が変わります。検証手順を残しておかないと再現できません。 |
| `getComputedStyle`の結果を過信する | ブラウザ間で正規化された値が返ることがあります（例: `rgb()` vs `rgba()`、フォントの実フォールバック）。比較の基準を統一してください。 |
| 手動検証を完全に省略する | UX判断は自動化できません。最低限のスモーク手動確認は残してください。 |
