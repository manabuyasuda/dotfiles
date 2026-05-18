# e2eテストのパターン

`test-target-classification.md`で「ユーザージャーニー（e2e）」と判別された場合に読みます。Playwrightを使用することを前提とします。

## 適用条件

- 複数ページ・複数コンポーネントにまたがる振る舞いを検証します
- 実ブラウザでの操作を再現します
- 由来UCが系統E（エンドユーザー × UI）または系統O（運用者 × 管理画面）の場合に適用します

視覚的な差分の検証は`visual-test-patterns.md`、サーバー側の状態変化は`integration-test-patterns.md`に寄せます。

## パターン判別

| パターン | 適用条件 | テストの観点 |
|---|---|---|
| 主シナリオ | 機能の正常系を最後まで通す | ユーザー目線で完了したことがUI上で明確 |
| 中断と再開 | ページリロード / タブ切替 / 戻るボタン | 状態の保持・復元 |
| 管理画面操作 | 系統Oのドライラン → 確認 → 実行フロー | 影響範囲プレビュー、確認ダイアログ、最終結果 |
| エラーリカバリ | 失敗状態からのユーザー操作での復帰 | エラー表示、再試行、入力保持 |

## 共通ルール

- ファイル先頭に`VERIFY:meta`を必ず追加します
- 2行目にテスト実行コマンドをコメントで記載します
- 要素の取得は`getByRole` > `getByLabel` > `getByText`の優先順で行います
- 1テスト1ジャーニーにします（複数の状況軸を同時検証しません）
- 状況軸の検証は下位のテスト種別に集約します（5xxはunit/componentで網羅し、e2eは1パターンのみ）
- 状態のセットアップはAPI経由で行います。UI操作でログイン → データ作成 → 検証のような長いセットアップは避けてください
- スクリーンショット比較は`visual-test-patterns.md`に寄せます

## ファイル配置と命名

```
e2e/
├── features/
│   ├── profile-avatar.spec.ts
│   └── admin-force-replace-avatar.spec.ts
└── fixtures/
    └── ...
```

または機能ディレクトリ内に置く方針の場合:

```
src/features/profile/
├── ...
└── profile.e2e.spec.ts
```

プロジェクトの既存構成に合わせます。

## 各パターンのテンプレート

### パターン1: 主シナリオ

```ts
// VERIFY:meta
//   対象機能:           プロフィール画像変更
//   想定ユーザー:       ログイン済みのエンドユーザー
//   目的:               プロフィール画像を新しい画像に置き換える
//   前提条件:           ログイン済み / 既存画像あり
//   起こり得る外部条件: cond.network (オフライン) / cond.external (ストレージAPI 5xx)
//   テスト範囲外:       内部APIの詳細 / モデレーション判定
//   最終レビュー日:     2026-05-13

// npx playwright test e2e/features/profile-avatar.spec.ts
import { test, expect } from '@playwright/test';
import { loginAs } from '../fixtures/auth';

test.describe('プロフィール画像変更', () => {
  test.beforeEach(async ({ page }) => {
    await loginAs(page, 'user-with-avatar');
    await page.goto('/profile');
  });

  test('画像を選択して保存できる', async ({ page }) => {
    await page.getByRole('button', { name: '画像を変更' }).click();
    await page.setInputFiles('input[type="file"]', 'fixtures/avatar.png');
    await expect(page.getByRole('img', { name: 'プレビュー' })).toBeVisible();

    await page.getByRole('button', { name: '保存' }).click();

    await expect(page.getByRole('status')).toHaveText('保存しました');
    await expect(page.getByTestId('header-avatar')).toHaveAttribute(
      'src',
      /\/avatar-\w+\.png$/
    );
  });
});
```

### パターン2: 中断と再開

ページリロード / タブ切替 / 戻るボタン後の状態を確認します。

```ts
// npx playwright test e2e/features/profile-avatar-resume.spec.ts
import { test, expect } from '@playwright/test';
import { loginAs } from '../fixtures/auth';

test.describe('プロフィール画像変更の中断と再開', () => {
  test('保存前にリロードしても入力が保持される', async ({ page }) => {
    await loginAs(page, 'user-with-avatar');
    await page.goto('/profile');

    await page.getByRole('button', { name: '画像を変更' }).click();
    await page.setInputFiles('input[type="file"]', 'fixtures/avatar.png');
    await expect(page.getByRole('img', { name: 'プレビュー' })).toBeVisible();

    await page.reload();

    // プレビューが復元されている、もしくは「保存されていない変更があります」が表示される
    // 仕様に応じてどちらかを期待値にする
    await expect(page.getByText('保存されていない変更があります')).toBeVisible();
  });

  test('保存中にナビゲーション離脱しようとすると警告が出る', async ({ page }) => {
    await loginAs(page, 'user-with-avatar');
    await page.goto('/profile');

    await page.getByRole('button', { name: '画像を変更' }).click();
    await page.setInputFiles('input[type="file"]', 'fixtures/avatar.png');

    page.on('dialog', async (dialog) => {
      expect(dialog.message()).toContain('保存されていない変更');
      await dialog.dismiss();
    });
    await page.goto('/');
  });
});
```

### パターン3: 管理画面操作（系統O）

ドライラン → 確認 → 実行のフローと、影響範囲プレビュー、確認ダイアログを確認します。

```ts
// VERIFY:meta
//   対象機能:           違反画像の強制差し替え（管理画面）
//   想定ユーザー:       コンテンツモデレーター
//   目的:               違反報告された画像をデフォルトに強制差し替えする
//   前提条件:           モデレーター権限 / 対象ユーザー特定済み
//   起こり得る外部条件: cond.external (キャッシュ無効化API)
//   テスト範囲外:       DB直接検証 (integrationで扱う) / 違反検出アルゴリズム
//   最終レビュー日:     2026-05-13

// npx playwright test e2e/features/admin-force-replace-avatar.spec.ts
import { test, expect } from '@playwright/test';
import { loginAs } from '../fixtures/auth';

test.describe('違反画像の強制差し替え', () => {
  test.beforeEach(async ({ page }) => {
    await loginAs(page, 'moderator-user');
    await page.goto('/admin/users');
  });

  test('ドライラン→確認→実行で完了する', async ({ page }) => {
    await page.getByRole('textbox', { name: 'ユーザーID' }).fill('target-user-123');
    await page.getByRole('button', { name: '検索' }).click();
    await expect(page.getByText('target-user-123')).toBeVisible();

    await page.getByRole('button', { name: '画像を強制差し替え' }).click();
    await page.getByRole('textbox', { name: '理由' }).fill('違反報告 #1234 への対応');

    await page.getByRole('button', { name: 'ドライラン' }).click();
    await expect(page.getByText('影響: ユーザー1名 / 関連投稿のサムネイル再生成')).toBeVisible();

    await page.getByRole('button', { name: '実行' }).click();
    await expect(page.getByRole('dialog')).toBeVisible();
    await page.getByRole('textbox', { name: '確認のため "REPLACE" と入力' }).fill('REPLACE');
    await page.getByRole('button', { name: '確認して実行' }).click();

    await expect(page.getByRole('status')).toHaveText('差し替えが完了しました');
  });

  test('理由を入力していない場合はドライランボタンを押せない', async ({ page }) => {
    await page.getByRole('textbox', { name: 'ユーザーID' }).fill('target-user-123');
    await page.getByRole('button', { name: '検索' }).click();
    await page.getByRole('button', { name: '画像を強制差し替え' }).click();

    await expect(page.getByRole('button', { name: 'ドライラン' })).toBeDisabled();
  });
});
```

サーバー側の状態変化（DBの`users.avatar_url`更新、`audit_logs`記録）は`integration-test-patterns.md`で別途検証します。e2eはUIを通じた操作完了までを担います。

### パターン4: エラーリカバリ

APIが失敗したときのUIを確認します。MSW / Playwrightの`route`でレスポンスを書き換えます。

```ts
// npx playwright test e2e/features/profile-avatar-error.spec.ts
import { test, expect } from '@playwright/test';
import { loginAs } from '../fixtures/auth';

test.describe('プロフィール画像変更のエラーリカバリ', () => {
  test.beforeEach(async ({ page }) => {
    await loginAs(page, 'user-with-avatar');
  });

  test('保存中にサーバーエラーが発生したとき再試行ボタンが出る（5xx）', async ({ page }) => {
    await page.route('**/api/avatar', (route) => {
      route.fulfill({ status: 500, body: 'Internal Server Error' });
    });

    await page.goto('/profile');
    await page.getByRole('button', { name: '画像を変更' }).click();
    await page.setInputFiles('input[type="file"]', 'fixtures/avatar.png');
    await page.getByRole('button', { name: '保存' }).click();

    await expect(page.getByRole('alert')).toHaveText('保存に失敗しました');
    await expect(page.getByRole('button', { name: '再試行' })).toBeVisible();
    await expect(page.getByRole('img', { name: 'プレビュー' })).toBeVisible();
  });

  test('オフラインで保存しようとするとオフライン用UIが出る', async ({ context, page }) => {
    await page.goto('/profile');
    await page.getByRole('button', { name: '画像を変更' }).click();
    await page.setInputFiles('input[type="file"]', 'fixtures/avatar.png');

    await context.setOffline(true);
    await page.getByRole('button', { name: '保存' }).click();

    await expect(page.getByRole('alert')).toHaveText('オフラインです');
  });
});
```

## Agentic Verificationとの組み合わせ

主シナリオは自動e2eで固定します。以下はVERIFYコメントでAgentic検証に寄せます。

- 実環境固有の挙動（CDN、実APIレスポンス）
- Performance metrics（LCP / CLS / INP）
- コンソールエラーの拾い上げ
- CSS実値の確認

```ts
test.describe('プロフィール画像変更', () => {
  // VERIFY:agentic
  //   検証内容:               保存後のCLSが0.1以下である
  //   検証手順:               1. Playwright MCPでプロフィール画面を開く 2. 画像変更→保存を実行 3. performance.getEntriesByType('layout-shift')を評価
  //   合格基準:               累積CLS値が0.1未満
  //   自動テスト化しない理由: Lighthouse CIで代替可能だが、特定操作シーケンス後の計測は難しい
  //   自動テスト化する条件:   CLSリグレッションが2回以上発生したらLighthouse CIシナリオに昇格

  test('画像を選択して保存できる', async ({ page }) => { /* ... */ });
});
```

## テスト実行

```bash
npx playwright test
npx playwright test e2e/features/xxx.spec.ts
```

## 設計改善のチェックリスト

### チェック1: e2eで複数の状況軸を同時検証していないか

「フォーム入力 + ネットワーク断 + 認証期限切れ」を1テストにまとめると失敗時に原因が分からなくなります。1テスト1状況軸が原則です。

### チェック2: APIセットアップをUI操作でやっていないか

「ログイン画面でログイン → 新規ユーザー作成 → プロフィール画面に遷移 → ...」のような長い前準備は不安定の原因です。`beforeEach`でAPI経由のセットアップに切り替えます。

### チェック3: 待ち合わせに`setTimeout`を使っていないか

`page.waitForSelector` / `expect().toBeVisible()`で待ちます。固定時間sleepは不安定です。

### チェック4: スクリーンショット比較をe2eに混ぜていないか

visual regressionは`visual-test-patterns.md`のStorybookベース構成に寄せると安定します。

### チェック5: 系統Eと系統Oのe2eを同じファイルに混ぜていないか

由来UCが違うe2eは別ファイルに分けます。失敗時に「ユーザー側の問題か、管理者側の問題か」を切り分けやすくなります。
