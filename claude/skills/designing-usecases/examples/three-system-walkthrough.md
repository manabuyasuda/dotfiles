# 同一機能を3系統で展開する例

題材はアバター画像のアップロード機能です。

同じ機能でも、系統ごとにユースケースが完全に別物になります。
主体・インターフェース・観察対象・テスト種別がすべて異なるため、テストケースも3系統それぞれに独立して必要であり、片方が他方を代替することはありません。

## UC-E-001: ユーザーがプロフィール画像を変える

- **系統**: E (エンドユーザー × UI)
- **主体**: ログイン済みエンドユーザー
- **目的**: 自分のプロフィール画像を新しいものに変えたい
- **前提条件**: ログイン済み、既存画像あり
- **トリガー**: プロフィール編集画面で「画像を変更」をタップ
- **主シナリオ**:
  1. ファイル選択ダイアログを開く
  2. 画像を選ぶ
  3. プレビューが表示される
  4. 「保存」をタップする
  5. 完了トーストが表示され、ヘッダーアバターも更新される
- **代替シナリオ**: トリミングUIを操作する / 既存画像をデフォルトに戻す
- **異常シナリオ**:
  - 巨大ファイル → クライアント側で拒否メッセージ
  - アップロード中の通信断 → 「再試行」ボタン提示
  - 不正なファイル形式 → エラー表示
- **適用される状況**: `cond.network` (オフライン), `cond.external` (ストレージAPI 5xx), `cond.runtime` (タブ切替後の戻り)
- **観察可能な期待結果**:
  - プレビュー画像が表示される
  - 保存後、ヘッダーアバターが新しい画像になる
  - 完了トーストが表示される
- **検証方法**:
  - 自動テスト:
    - e2e: 主シナリオ + 通信断パターン
    - visual: プレビュー画面、トリミングUI
    - a11y: キーボードのみで完遂、ファイル選択のフォーカス管理
  - Agentic Verification:
    - Playwright MCP で実操作 → ファイル選択 → プレビュー → 保存までを通し、各ステップでスクショ
    - `getComputedStyle()` でアバター画像の `object-fit` / `border-radius` 実値を確認
    - `performance.getEntriesByType('layout-shift')` で保存後の CLS 実測
    - コンソールエラーが出ていないか `Page.consoleAPICalled` 等で監視
- 非対象: 内部で叩かれるAPIの詳細は UC-D-001 で扱う / モデレーション対象判定は UC-O-001

## UC-D-001: 開発者が `<AvatarUploader>` をフォームに組み込む

- **系統**: D (開発者 × コードAPI)
- **主体**: このコンポーネントを使う側のフロントエンド開発者
- **目的**: 自分のフォームに画像アップロードUIを差し込み、選択された画像URLを取得したい
- **前提条件**: React 18+、Peer Deps を満たした環境
- **公開シグネチャ**:
  ```ts
  type AvatarUploaderProps = {
    initialUrl?: string;
    onUploaded: (url: string) => void;
    onError?: (e: UploadError) => void;
    maxBytes?: number; // default: 5_000_000
    accept?: string[]; // default: ['image/png', 'image/jpeg']
  };
  ```
- **主シナリオ**:
  1. 必須propsのみでマウント
  2. ユーザーが選択（テスト内では `userEvent.upload`）
  3. `onUploaded` が新しい URL 引数で呼ばれる
- **代替シナリオ**:
  - `maxBytes` 指定時、超過ファイルで `onError` が呼ばれる
  - `onError` 未指定時、コンソール warning が出る
  - Suspense境界内で使用
  - controlled / uncontrolled の両方
- **異常シナリオ**:
  - `onUploaded` 未指定 → 型エラー（コンパイル時）
  - `initialUrl` に不正な値 → ランタイムで明確に reject
  - アップロード中に unmount → AbortSignal 経由で中断
- **適用される状況**: `cond.external` (API レスポンス揺れ、5xx), `cond.network` (AbortSignal の伝搬)
- **観察可能な期待結果**:
  - コールバックの呼び出し回数・引数
  - 発火するエラーの型（`UploadError` の discriminated union）
  - unmount 時の cleanup 完了
- **検証方法**:
  - 自動テスト:
    - unit: props の各組み合わせ、コールバック発火
    - 型テスト (tsd): 必須/任意 props の型エラー、`UploadError` の narrowing
    - build smoke: ESM/CJS の両方から import できる、`/* "sideEffects": false */` で tree-shake される
    - bundle size: gzip 後 8KB 以下を assertion
  - Agentic Verification:
    - 最小サンプル React アプリを `/tmp/sandbox` に作成 → `npm install` → `npm run build` 実行
    - 生成された `dist/main.js` を grep して `<AvatarUploader>` 未使用時のコードが落ちることを実証
    - `tsc --noEmit` で `onUploaded` を省略した場合のエラーメッセージが分かりやすいか直接確認
    - Vite / webpack / Rspack の3バンドラーで実ビルドして比較
- 非対象: 画面上の見え方（プレビュー位置、トーストデザイン等）は UC-E-001 / 違反画像の判定は UC-O-001

## UC-O-001: 運用者が違反画像を強制差し替える

- **系統**: O (運用者 × 管理画面)
- **主体**: コンテンツモデレーター（権限ロール: `moderator`）
- **目的**: 違反報告された画像を、デフォルト画像に強制差し替える
- **前提条件**: モデレーター権限、対象ユーザーIDが特定済み、違反報告チケットあり
- **トリガー**: 違反報告のレビュー結果
- **主シナリオ**:
  1. 管理画面で対象ユーザーを検索
  2. 「画像を強制差し替え」を選ぶ
  3. 差し替え理由を入力（必須、監査ログ用）
  4. ドライラン結果を確認（影響範囲のプレビュー）
  5. 実行する
  6. 対象ユーザーに通知が飛ぶ（設定により）
- **影響範囲**:
  - 対象1ユーザーのプロフィール画像
  - CDN キャッシュ無効化
  - 関連するコメント/投稿のサムネイル再生成（非同期）
- **代替シナリオ**:
  - ドライランのみで終了
  - 一時凍結（差し替えではなく非表示）
- **異常シナリオ**:
  - モデレーター以外のロール → 403、そもそも UI にメニューが出ない
  - 並行で同ユーザーを別モデレーターが操作中 → 楽観ロックで2人目はリトライ要求
  - キャッシュ無効化の失敗 → 部分成功扱い、リトライ可能
- **適用される状況**: `cond.external` (キャッシュ無効化APIの遅延・失敗), `cond.time` (CDN TTL の影響)
- **観察可能な期待結果**:
  - DB の `users.avatar_url` がデフォルト画像に更新
  - `audit_logs` テーブルに「誰が / いつ / 誰の / なぜ」が記録
  - CDN のキャッシュが無効化される
  - 対象ユーザーへの通知（設定による）
- **検証方法**:
  - 自動テスト:
    - integration: DB変更、監査ログ書き込み、キャッシュ無効化API呼び出し
    - 管理画面 e2e: 主シナリオ（ドライラン → 実行）
    - 権限境界テスト: `admin` / `moderator` / `support` / `member` の各ロールでの可否
    - 監査ログ検証: 操作者ID、対象ユーザーID、理由、タイムスタンプの記録
  - Agentic Verification (ステージング限定):
    - ブラウザMCPで `moderator` ロールでログイン → 強制差し替え操作 → ドライラン結果のスクショ
    - DB MCP で `audit_logs` テーブルから直近のレコードを SELECT し、記録項目を確認
    - DB MCP で `users.avatar_url` の更新前後を比較
    - 別ロール（`support`）で同URLを叩いて 403 が返ることを直接確認
    - 実 CDN へリクエストしてキャッシュヘッダ確認
- 非対象: 対象ユーザーが画面上でどう見えるかは UC-E-001（ユーザーがプロフィール画像を変えるUC）の派生として別途記述 / 違反検出のアルゴリズム自体は別UC

## なぜ3つを別々に書く必要があるのか

仮にこの機能を「ユーザーが画像を変える」UC一本にまとめると、以下の観点が抜けます。

| 抜ける観点 | どのUCで担保すべきだったか |
|---|---|
| `<AvatarUploader>` の bundle size、tree-shaking | UC-D-001 |
| `<AvatarUploader>` の型レベルの保証（必須props欠落の検出） | UC-D-001 |
| ESM/CJS 両方からのimport可能性 | UC-D-001 |
| モデレーターの権限境界（`support` ロールが叩いたら拒否されるか） | UC-O-001 |
| 監査ログの記録項目 | UC-O-001 |
| ドライランによる影響範囲プレビュー | UC-O-001 |
| キャッシュ無効化の遅延・失敗 | UC-O-001（系統O側の観察対象） |

これらは UC-E-001 の観点リストには登場しません（登場すべきでもありません）。
よって同じ機能でも、系統ごとにUCを書き、それぞれにテストケースを展開する必要があります。

## テストファイル構成への反映

3系統のテストは別ファイルに分けます。混在させると失敗時の原因系統が不明瞭になります。

```
src/
├── components/
│   └── AvatarUploader/
│       ├── AvatarUploader.tsx
│       ├── AvatarUploader.unit.test.ts        # UC-D-001 (unit)
│       ├── AvatarUploader.types.test-d.ts     # UC-D-001 (型テスト)
│       └── AvatarUploader.bundle.test.ts      # UC-D-001 (bundle size)
└── features/
    └── profile/
        ├── profile.e2e.spec.ts                # UC-E-001 (e2e)
        ├── profile.visual.spec.ts             # UC-E-001 (visual)
        └── admin/
            ├── force-avatar-replace.integration.test.ts  # UC-O-001
            ├── force-avatar-replace.e2e.spec.ts          # UC-O-001
            └── force-avatar-replace.permission.test.ts   # UC-O-001
```
