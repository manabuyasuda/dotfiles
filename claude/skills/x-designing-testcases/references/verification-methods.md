# 検証方法（3層検証）

「テスト = テストコードを書く」ではありません。検証は3層で考えます。UCから検証手段を割り当てるとき、自動テストだけでなくAgentic Verification（エージェント駆動検証）と手動検証も選択肢に含めます。

## 1. 検証の3層

| 層 | 主な目的 | 実行頻度 | 主な担い手 |
|---|---|---|---|
| 自動テスト | 退行検知 | CIで常時 | テストランナー |
| Agentic Verification | 仕様確定 / 不具合再現 / 実環境の実値確認 | 開発中・必要時 | Claude Code等のエージェント |
| 手動検証 | UX判断 / 新規体験の評価 / 最終受け入れ | リリース前 | 人間 |

3つは排他ではなく補完関係です。Agentic Verificationで確認したことは、退行検知が必要と判断した場合に自動テストへ昇格させます。

このスキルでは、3層の情報をテストファイル内に併記する設計を取ります。

- 自動テスト = `it()` / `test()`の本体（CIで実行）
- Agentic Verification = `VERIFY:agentic`コメント（エージェントがgrepして実行）
- 手動検証 = `VERIFY:manual`コメント（エージェントがgrepしてユーザーに渡す）

コメント仕様は`verify-comment-spec.md`を参照してください。

## 2. 自動テスト

退行検知のためCIで繰り返し実行します。実装パターンは`test-target-classification.md`で対象を判別後、対応するpattern referenceを読んでください。

高頻度で回せるため、失敗を即座に検出できます。一方、書くコストが高く、実環境固有の挙動（CDN、実ブラウザ、CSSの実適用値）は拾いきれないことが多い点に注意してください。

## 3. Agentic Verification

エージェント（Claude Code等）が実環境で直接検証する手段です。テストコードを書かずに、その場で確認します。

### 3.1 主な手段

#### (a) ブラウザ操作MCP

Chrome DevTools MCPまたはPlaywright MCPを使い、ページを開く / 要素クリック / フォーム入力 / スクショ取得 / コンソールログ取得 / ネットワーク監視 / Performance計測 / a11y treeを取得します。主な用途は次の通りです。

- 実際にUI操作して、画面遷移と表示を確認します
- フォーカス順序、タブキー移動を実際に確認します
- コンソールエラー / 警告を検出します
- ステージング環境での管理画面の操作を確認します

#### (b) JSでの実値取得（ブラウザコンテキスト内で評価）

ブラウザMCP経由で`evaluate` / `runtime.evaluate`系を使い、実際の値を取得します。

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

主な用途は次の通りです。

- 「CSSが意図通り適用されているか」を実値で確認します（visual regressionより直接的）
- CLS / LCP / INPを実測します
- SSRハイドレーション後のDOM構造を確認し、コンソールエラーを拾い上げます
- 実バンドルでどのコードが含まれているかを確認します

#### (c) コード実行（Claude Codeネイティブ）

ファイルを書く / コマンドを実行する標準ツールで完結する検証手段です。主な用途は次の通りです。

- ビルド成果物を直接検査します（`dist/`をgrepする、ASTで確認するなど）
- 実際にミニサンプルを書いてバンドルし、tree-shakingの結果を確認します
- TypeScriptの`tsc --noEmit`を実行して型エラーを確認します
- APIをcurlで叩いてレスポンスを直接確認します

#### (d) 連携先MCP

データベースMCP / GitHub MCP / Slack MCP等を使い、副作用の発生先を直接確認します。主な用途は次の通りです。

- DBの状態変化を実SQLで確認します
- 監査ログテーブルの実レコードを検査します

### 3.2 強みと弱み

主な強みは次の通りです。

- テストコードを書く前に「動く・動かない」「実値はこうなっている」を即確認できます
- 実環境固有の挙動（実ブラウザ、実CDN、実APIレスポンス）を直接見られます
- 仕様確定段階で、書くべき自動テストの輪郭を明確化できます

主な弱みは次の通りです。

- 再現性が低いです。次回同じ確認をするには再度エージェントを動かす必要があります
- 退行検知に弱く、毎回確認しないと壊れたことに気づけません
- 環境に依存します。ローカル / ステージング / 本番で結果が変わります

### 3.3 自動テストへの昇格基準

Agentic Verificationで見つけたものは、以下に当てはまれば自動テストに昇格させます。

- [ ] 一度直しても再発する可能性があります
- [ ] 退行したら影響が大きいです
- [ ] アサーションが安定して書けます（揺れの少ない期待値が定義できます）
- [ ] 実行コストが妥当です（e2eで5分以上かかるなら整理します）

逆に、以下は自動テストにせずAgentic Verificationのまま残してよいです。

- 一度きりの仕様確認で済む場合
- 探索的な不具合調査が目的の場合
- アサーションが揺れやすい場合（UX的判断、複雑なレイアウト）
- 実環境でしか再現しない場合（CDN設定の確認等）

VERIFYコメントに「自動テスト化する条件」を書いておくと、エージェントが定期的に評価して昇格提案できます。

## 4. 手動検証

人間の目視・操作で確認します。Agentic Verificationでも代替できないものを残します。

- UX判断（「使いやすいか」「直感的か」）を行います
- 新規体験を最終評価します
- 微細なアニメーション・トランジションの自然さを確認します
- アクセシビリティを実機で確認します（実スクリーンリーダー、実支援技術）
- 多言語の意味ニュアンスを確認します

手動検証は人によって結果がブレないように、`VERIFY:manual`の`検証手順`フィールドに何をどの順番で実行するかを具体的に書きます。

## 5. UCの観点から検証方法への割当て指針

各UCの「適用される状況軸」と「観察可能な期待結果」に対し、3層のどれで検証するかを割り当てます。1観点に複数層を割り当ててよいです（例: 自動テストで退行検知 + Agenticによる実値確認）。

### 系統Eの典型パターン

| 観点 | 自動テスト | Agentic Verification | 手動 |
|---|---|---|---|
| 主要ジャーニー | e2e | Playwright MCPで実操作 | リリース前確認 |
| 入力バリエーション | component test | — | — |
| エラーリカバリの表示 | component test + visual | ブラウザMCPでエラー発火させて画面確認 | — |
| アクセシビリティ（キーボード/フォーカス） | a11y test (component) | Chrome DevTools MCPでa11y tree取得、フォーカス順序確認 | 実スクリーンリーダー |
| CSS適用値 | visual regression | `getComputedStyle()`で実値取得 | — |
| CLS / LCP | Lighthouse CI | `performance.getEntries*()`で実測 | — |
| デバイス多様性 | visual（複数viewport） | ブラウザMCPでviewport切替 | 実機確認 |

### 系統Dの典型パターン

| 観点 | 自動テスト | Agentic Verification | 手動 |
|---|---|---|---|
| 公開API契約（runtime） | unit (domain / utils) | 最小サンプル書いて実行 | — |
| 副作用と状態遷移 | unit (domain) | サンドボックスで実呼び出し、グローバル状態を直接観測 | — |
| 拡張性 | component test | 実プロジェクトに組み込んで挙動確認 | — |
| Tree Shaking | （品質ゲート: bundle size assertionで担保。本スキル対象外） | 実バンドル成果物をgrep / ASTで検査 | — |
| SSR `window`ガード | hooks test (jsdom + node 両方) | Next.js 実プロジェクトで SSR 実行、コンソールエラー確認 | — |

### 系統Oの典型パターン

| 観点 | 自動テスト | Agentic Verification | 手動 |
|---|---|---|---|
| 権限境界 | integration（権限境界観点） | ステージングで各ロールでログインして実確認 | — |
| 監査ログ | integration（監査ログ観点） | DB MCPで`audit_logs`テーブル直接検査 | — |
| 影響範囲プレビュー | e2e（管理画面操作観点） | ブラウザMCPでドライラン実行して結果確認 | — |
| キャッシュ無効化 | integration | 実CDNへのリクエストヘッダー確認、ブラウザMCPで再取得 | — |
| 並行操作 | integration（並行操作観点） | 2セッション同時操作（ステージング） | — |

## 6. 落とし穴

| 落とし穴 | 対処 |
|---|---|
| Agentic Verificationを「テスト書かなくていい言い訳」にする | 退行検知が必要なものは自動テストに昇格させます。Agenticは仕様確定 / 探索が本領です。 |
| 本番環境でAgentic Verificationを回す | 副作用のある操作（とくに系統O）は必ずステージングで実行します。本番でやる場合はread-onlyに限定します。 |
| MCPの設定差で結果がブレる | ブラウザMCPのバージョン、ヘッドレス/有頭、viewport設定で結果が変わります。検証手順をVERIFYコメントに残しておきます。 |
| `getComputedStyle`の結果を過信する | ブラウザ間で正規化された値が返ることがあります（例: `rgb()` vs `rgba()`、フォントの実フォールバック）。比較の基準を統一します。 |
| 手動検証を省略する | UX判断は自動化できません。最低限のスモーク手動確認は`VERIFY:manual`として残します。 |
