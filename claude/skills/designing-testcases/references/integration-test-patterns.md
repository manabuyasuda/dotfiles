# integrationテストのパターン

`test-target-classification.md`で「サーバー側の状態変化を伴う統合」と判別された場合に読みます。Vitest + 実DB（またはtestcontainers）を使用する前提です。

## 適用条件

- 由来UCが系統O（運用者）または、系統Eでもサーバー側の状態変化を確認したい場合に適用します
- DBの状態変化、監査ログ記録、権限境界の確認、並行操作の整合性を検証します
- 実HTTPリクエスト・実DBを介したフロー全体を確認します

UIを介した検証は`e2e-test-patterns.md`に寄せます。integrationはAPI / DBレイヤーでの観察に集中します。

## パターン判別

| パターン | 適用条件 | テストの観点 |
|---|---|---|
| DB変更の検証 | 操作後のDBレコードを確認 | 期待するレコードが存在 / 更新 / 削除されている |
| 監査ログ | 操作の証跡を確認 | 監査ログテーブルに記録される、who/what/when/whyが揃う |
| 権限境界 | ロール別の許可・拒否を確認 | 権限のあるロール: 成功、ないロール: 403 |
| 並行操作 | 同一対象への同時更新 | 楽観ロックや最後書き勝ちの挙動が定義通り |

## 共通ルール

- ファイル先頭に`VERIFY:meta`を必ず追加します
- 2行目にテスト実行コマンドをコメントで記載します
- 各テスト前にDBをクリーンな状態に戻します（`beforeEach`でtruncate / migrationリセット / トランザクションロールバック）
- テストは並列実行を想定して、ユーザーID・データ名にユニークsuffixを付けます
- 実HTTPリクエストを送る場合は`fetch`またはsupertestを使います
- DBアクセスはproductionと同じORM / クライアントを使います（テストだけ別ORMにしません）

## ファイル配置と命名

```
integration/
├── features/
│   ├── avatar-update.integration.test.ts
│   └── admin-force-replace-avatar.integration.test.ts
└── fixtures/
    └── ...
```

または機能ディレクトリ内:

```
src/features/profile/
├── ...
└── profile.integration.test.ts
```

## 各パターンのテンプレート

### パターン1: DB変更の検証

```ts
// VERIFY:meta
//   対象機能:           プロフィール画像更新APIによるDB変更
//   想定ユーザー:       APIを呼ぶエンドユーザー（クライアント経由）
//   目的:               画像URLがusersテーブルに正しく保存される
//   前提条件:           対象ユーザーが存在
//   起こり得る外部条件: cond.external (ストレージAPI失敗) / cond.network (中断)
//   テスト範囲外:       UIからの操作 (e2eで扱う) / 認可ロジック (権限境界テストで扱う)
//   最終レビュー日:     2026-05-13

// npm run test:integration -- integration/features/avatar-update.integration.test.ts
import { describe, it, expect, beforeEach } from 'vitest';
import { db } from '@/lib/db';
import { createTestUser, withAuthToken } from '../fixtures/auth';

describe('プロフィール画像更新API', () => {
  let userId: string;
  let token: string;

  beforeEach(async () => {
    await db.users.deleteMany({ where: { email: { contains: 'integration-test-' } } });
    const user = await createTestUser({ avatarUrl: 'https://example.com/old.png' });
    userId = user.id;
    token = await withAuthToken(user);
  });

  it('画像を更新するとDBに新しいURLが保存される', async () => {
    const response = await fetch('http://localhost:3000/api/avatar', {
      method: 'PUT',
      headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ url: 'https://example.com/new.png' }),
    });

    expect(response.status).toBe(200);

    const user = await db.users.findUnique({ where: { id: userId } });
    expect(user?.avatar_url).toBe('https://example.com/new.png');
  });

  it('不正なURL形式は拒否され、DBが変わらない', async () => {
    const before = await db.users.findUnique({ where: { id: userId } });

    const response = await fetch('http://localhost:3000/api/avatar', {
      method: 'PUT',
      headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ url: 'not-a-url' }),
    });

    expect(response.status).toBe(422);

    const after = await db.users.findUnique({ where: { id: userId } });
    expect(after?.avatar_url).toBe(before?.avatar_url);
  });
});
```

### パターン2: 監査ログ

「誰が / 何を / いつ / なぜ」が記録されることを確認します。

```ts
// npm run test:integration -- integration/features/audit-log.integration.test.ts
import { describe, it, expect, beforeEach } from 'vitest';
import { db } from '@/lib/db';
import { createTestUser, withAuthToken, createTestModerator } from '../fixtures/auth';

describe('違反画像の強制差し替え時の監査ログ', () => {
  let targetUserId: string;
  let moderatorId: string;
  let moderatorToken: string;

  beforeEach(async () => {
    await db.audit_logs.deleteMany({ where: { action: 'force_replace_avatar' } });
    const target = await createTestUser({ avatarUrl: 'https://example.com/bad.png' });
    targetUserId = target.id;

    const moderator = await createTestModerator();
    moderatorId = moderator.id;
    moderatorToken = await withAuthToken(moderator);
  });

  it('強制差し替え操作が監査ログに記録される', async () => {
    const response = await fetch(
      `http://localhost:3000/api/admin/users/${targetUserId}/avatar`,
      {
        method: 'DELETE',
        headers: {
          Authorization: `Bearer ${moderatorToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ reason: '違反報告 #1234 への対応' }),
      }
    );

    expect(response.status).toBe(200);

    const log = await db.audit_logs.findFirst({
      where: { action: 'force_replace_avatar', target_id: targetUserId },
    });

    expect(log).toBeDefined();
    expect(log?.actor_id).toBe(moderatorId);
    expect(log?.target_id).toBe(targetUserId);
    expect(log?.reason).toBe('違反報告 #1234 への対応');
    expect(log?.created_at).toBeInstanceOf(Date);
  });

  it('理由欄が空だと操作が拒否され、ログも記録されない', async () => {
    const response = await fetch(
      `http://localhost:3000/api/admin/users/${targetUserId}/avatar`,
      {
        method: 'DELETE',
        headers: {
          Authorization: `Bearer ${moderatorToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ reason: '' }),
      }
    );

    expect(response.status).toBe(422);

    const log = await db.audit_logs.findFirst({
      where: { action: 'force_replace_avatar', target_id: targetUserId },
    });
    expect(log).toBeNull();
  });
});
```

### パターン3: 権限境界

権限のあるロール・ないロールの両方を必ず網羅します。

```ts
// npm run test:integration -- integration/features/permission-boundary.integration.test.ts
import { describe, it, expect, beforeEach } from 'vitest';
import { createTestUser, withAuthToken, createTestModerator, createTestAdmin } from '../fixtures/auth';

describe('違反画像の強制差し替え 権限境界', () => {
  let targetUserId: string;

  beforeEach(async () => {
    const target = await createTestUser({ avatarUrl: 'https://example.com/bad.png' });
    targetUserId = target.id;
  });

  it.each([
    { role: 'moderator', expectedStatus: 200, desc: 'モデレーターは実行できる' },
    { role: 'admin',     expectedStatus: 200, desc: 'アドミンは実行できる' },
    { role: 'user',      expectedStatus: 403, desc: '一般ユーザーは拒否される' },
    { role: 'anonymous', expectedStatus: 401, desc: '認証されていないリクエストは拒否される（401）' },
  ])('$desc', async ({ role, expectedStatus }) => {
    let token: string | undefined;
    if (role === 'moderator') {
      token = await withAuthToken(await createTestModerator());
    } else if (role === 'admin') {
      token = await withAuthToken(await createTestAdmin());
    } else if (role === 'user') {
      token = await withAuthToken(await createTestUser({}));
    }

    const response = await fetch(
      `http://localhost:3000/api/admin/users/${targetUserId}/avatar`,
      {
        method: 'DELETE',
        headers: {
          ...(token ? { Authorization: `Bearer ${token}` } : {}),
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ reason: 'テスト' }),
      }
    );

    expect(response.status).toBe(expectedStatus);
  });
});
```

横方向のアクセス（同じロールでも他テナント/他ユーザーのデータに触れない）も確認します。

```ts
it('同じロールでも他テナントのユーザーは操作できない', async () => {
  const tenantAUser = await createTestUser({ tenantId: 'tenant-a' });
  const tenantBModerator = await createTestModerator({ tenantId: 'tenant-b' });
  const token = await withAuthToken(tenantBModerator);

  const response = await fetch(
    `http://localhost:3000/api/admin/users/${tenantAUser.id}/avatar`,
    {
      method: 'DELETE',
      headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ reason: 'テスト' }),
    }
  );

  expect(response.status).toBe(403);
});
```

### パターン4: 並行操作

同一対象への同時更新で、楽観ロックや最後書き勝ちの挙動が定義通りになることを確認します。

```ts
// npm run test:integration -- integration/features/concurrent-update.integration.test.ts
import { describe, it, expect, beforeEach } from 'vitest';
import { db } from '@/lib/db';
import { createTestUser, withAuthToken } from '../fixtures/auth';

describe('プロフィール更新の並行操作', () => {
  let userId: string;
  let token: string;

  beforeEach(async () => {
    const user = await createTestUser({ name: 'initial', version: 1 });
    userId = user.id;
    token = await withAuthToken(user);
  });

  it('同じデータを同時に更新しようとすると片方だけ成功する', async () => {
    const update1 = fetch('http://localhost:3000/api/profile', {
      method: 'PUT',
      headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ name: 'updated by A', version: 1 }),
    });
    const update2 = fetch('http://localhost:3000/api/profile', {
      method: 'PUT',
      headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ name: 'updated by B', version: 1 }),
    });

    const [res1, res2] = await Promise.all([update1, update2]);

    const statuses = [res1.status, res2.status].sort();
    expect(statuses).toEqual([200, 409]);

    const user = await db.users.findUnique({ where: { id: userId } });
    expect(['updated by A', 'updated by B']).toContain(user?.name);
    expect(user?.version).toBe(2);
  });
});
```

## セットアップ方針

- トランザクションロールバック: 各テストをトランザクション内で実行し、終了時にrollbackします。並列実行と相性が悪い点に注意してください
- truncateベース: `beforeEach`で関連テーブルをtruncateします。シンプルですが並列実行時に競合する場合があります
- スキーマ分離: テストごとにDBスキーマ / 名前空間を分けます。独立性が高いですがsetupコストもかかります
- testcontainers: PostgreSQL / MySQLをテスト時だけDockerで起動します。CIで安定しますがローカル開発で起動コストがかかります

プロジェクトの方針に合わせて選びます。新規導入ならtruncateベース + ユニークsuffixがもっとも簡単です。

## テスト実行

```bash
npm run test:integration
npm run test:integration -- integration/features/xxx.integration.test.ts
```

整合性のため、integrationテストはunitテストと別のスクリプトに分けることを推奨します。

## Agentic Verificationとの組み合わせ

ステージング環境での副作用確認はVERIFYコメントでAgentic検証に寄せます。

```ts
// VERIFY:agentic
//   検証内容:               本番に近いステージングでの監査ログ記録
//   検証手順:               1. ステージングDB MCPに接続 2. audit_logsをtail -f的に監視 3. 管理画面で強制差し替えを実行 4. 直後にaudit_logsを再取得
//   合格基準:               action='force_replace_avatar', actor_id, target_id, reasonの4フィールドが揃っている
//   自動テスト化しない理由: ステージング環境固有の挙動（実IAM権限、実S3連携）を確認したい
//   自動テスト化する条件:   integrationテストでの再現性が確立できればautomatedに昇格
```

## 設計改善のチェックリスト

### チェック1: 副作用の確認が外部APIモックで止まっていないか

「外部APIがコールされた」だけ確認して終わらせず、自分のサービス側のDBがどう変化したかを必ず確認します。

### チェック2: 権限のないロールでの拒否確認が抜けていないか

「権限のあるロールで成功する」だけだと境界の検証が不十分です。`it.each`で全ロールを網羅します。

### チェック3: 監査ログのフィールドを全部確認しているか

「ログが1件記録された」だけでは不十分です。who / what / when / whyの4要素をすべて確認します。

### チェック4: 並行操作の検証で`Promise.all`以外の方法を使っているか

`Promise.all`で並列リクエストを送るだけでは「ほぼ同時」になりますが、DBレベルでは順序が確定します。本当のレース条件を再現するには、SQLレベルでの先後関係を制御する必要となることがあります。

### チェック5: テストデータ作成をfixture化しているか

各テストで`createTestUser`、`createTestModerator`のようなfixture関数を使います。インラインで`db.users.create()`を書くと冗長になり、スキーマ変更時の影響範囲も広がります。
