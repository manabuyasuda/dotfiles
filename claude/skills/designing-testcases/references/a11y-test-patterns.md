# a11yテストのパターン

`test-target-classification.md`で「キーボード操作 / フォーカス / aria属性の動的な更新」と判別された場合に読みます。component testを中心に、Vitest + `@testing-library/react` + `@testing-library/user-event`を使います。

## スコープ

このスキルで扱うのは「動的な振る舞い」だけです。以下は対象外です。

| 対象外 | 担当 |
|---|---|
| color-contrast | axe / markuplint |
| 静的なaria属性の存在 | axe / markuplint |
| button-name / heading-order等の静的構造 | axe / markuplint |
| 静的なフォーカス可能性（tabindexの有無） | axe / markuplint |
| 実スクリーンリーダーでの読み上げの意味的自然さ | `VERIFY:manual` |

このファイルでテストする対象は以下の通りです。

- キーボード操作: Tab / Shift+Tab / Enter / Space / 矢印キー / Escで意図通り操作できること
- フォーカス管理: モーダル開閉時のフォーカス移動、フォーカストラップ、unmount時の戻し先が正しいこと
- 動的aria属性: 状態変化に伴う`aria-expanded` / `aria-selected` / `aria-pressed`が更新されること
- 動的なライブリージョン: `role="alert"` / `role="status"` / `aria-live`が正しく発火すること
- フォームエラーの通知: バリデーションエラー時に`aria-invalid` / `aria-describedby`が設定されエラーメッセージが読み上げられること

## パターン判別

| パターン | 適用条件 | テストの観点 |
|---|---|---|
| キーボード操作 | クリックでなくキーボードでも完遂できる | Tab順序、Enter / Spaceで動作、矢印キーで選択 |
| フォーカストラップ | モーダル / ダイアログを持つ | 開いている間、Tabがモーダル内で循環、Escで閉じる |
| フォーカス復元 | ポップアップ・ダイアログを閉じる | 開く前の要素に戻る |
| aria属性の動的な更新 | トグル・展開・選択を持つ | 状態変化でaria属性が更新される |
| ライブリージョン | 動的な通知・エラーを持つ | 通知発火時に`role="status"` / `role="alert"`を持つ要素が現れる |
| バリデーションエラーのaria属性設定 | バリデーションエラーを持つフォームフィールド | エラー時に`aria-invalid="true"` + `aria-describedby`が設定され、エラーメッセージが`role="alert"` / `aria-live`で通知される |

## 共通ルール

- ファイル先頭に`VERIFY:meta`を必ず追加します
- 2行目にテスト実行コマンドをコメントで記載します
- 要素取得は`getByRole`を最優先にします（a11yを扱う以上、roleによる取得が一致しないと意味がありません）
- `userEvent.keyboard()`でキー操作を再現します
- `document.activeElement`でフォーカス位置を確認します

## ファイル配置と命名

component単位でa11yテストを切り出す場合:

```
src/components/Modal/
├── Modal.tsx
├── Modal.test.tsx        ← 通常の振る舞いテスト
└── Modal.a11y.test.tsx   ← a11y専用
```

またはcomponent testに同居させてもよいです（プロジェクトの方針に合わせてください）。

## 各パターンのテンプレート

### パターン1: キーボード操作

```tsx
// VERIFY:meta
//   対象機能:           ドロップダウンメニューのキーボード操作
//   想定ユーザー:       キーボードのみで操作するユーザー
//   目的:               マウスを使わずに項目を選択できる
//   前提条件:           none
//   起こり得る外部条件: none
//   テスト範囲外:       実スクリーンリーダーでの読み上げ (VERIFY:manualで扱う) / 静的aria属性 (axeで担保)
//   最終レビュー日:     2026-05-13

// npm run test:run -- src/components/DropdownMenu/DropdownMenu.a11y.test.tsx
import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { DropdownMenu } from './DropdownMenu';

describe('DropdownMenuキーボード操作', () => {
  it('Enterキーでメニューを開ける', async () => {
    const user = userEvent.setup();
    render(<DropdownMenu items={['A', 'B', 'C']} />);
    const trigger = screen.getByRole('button', { name: 'メニュー' });
    trigger.focus();

    await user.keyboard('{Enter}');

    expect(screen.getByRole('menu')).toBeVisible();
  });

  it('矢印キーで次の項目にフォーカスが移る', async () => {
    const user = userEvent.setup();
    render(<DropdownMenu items={['A', 'B', 'C']} defaultOpen />);
    const items = screen.getAllByRole('menuitem');
    items[0].focus();

    await user.keyboard('{ArrowDown}');

    expect(document.activeElement).toBe(items[1]);
  });

  it('矢印キーを末尾の項目で押すと先頭にフォーカスが移る', async () => {
    const user = userEvent.setup();
    render(<DropdownMenu items={['A', 'B', 'C']} defaultOpen />);
    const items = screen.getAllByRole('menuitem');
    items[2].focus();

    await user.keyboard('{ArrowDown}');

    expect(document.activeElement).toBe(items[0]);
  });

  it('Escキーで閉じる', async () => {
    const user = userEvent.setup();
    render(<DropdownMenu items={['A', 'B', 'C']} defaultOpen />);

    await user.keyboard('{Escape}');

    expect(screen.queryByRole('menu')).not.toBeInTheDocument();
  });
});
```

### パターン2: フォーカストラップ

モーダルが開いている間、Tabがモーダル内で循環することを確認します。

```tsx
// npm run test:run -- src/components/Modal/Modal.a11y.test.tsx
import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { Modal } from './Modal';

describe('Modalフォーカストラップ', () => {
  it('Tabを押すとモーダル内の次の要素にフォーカスが移る', async () => {
    const user = userEvent.setup();
    render(
      <Modal isOpen onClose={() => {}}>
        <button>最初</button>
        <button>真ん中</button>
        <button>最後</button>
      </Modal>
    );
    const first = screen.getByRole('button', { name: '最初' });
    const middle = screen.getByRole('button', { name: '真ん中' });
    first.focus();

    await user.tab();

    expect(document.activeElement).toBe(middle);
  });

  it('Tabをモーダルの最後の要素で押すと先頭にフォーカスが移る', async () => {
    const user = userEvent.setup();
    render(
      <Modal isOpen onClose={() => {}}>
        <button>最初</button>
        <button>真ん中</button>
        <button>最後</button>
      </Modal>
    );
    const first = screen.getByRole('button', { name: '最初' });
    const last = screen.getByRole('button', { name: '最後' });
    last.focus();

    await user.tab();

    expect(document.activeElement).toBe(first);
  });

  it('Shift+Tabでフォーカスが逆方向に循環する', async () => {
    const user = userEvent.setup();
    render(
      <Modal isOpen onClose={() => {}}>
        <button>最初</button>
        <button>最後</button>
      </Modal>
    );
    const first = screen.getByRole('button', { name: '最初' });
    const last = screen.getByRole('button', { name: '最後' });
    first.focus();

    await user.tab({ shift: true });

    expect(document.activeElement).toBe(last);
  });
});
```

### パターン3: フォーカス復元

ダイアログを閉じたとき、開く前の要素にフォーカスが戻ることを確認します。

```tsx
// npm run test:run -- src/components/Modal/Modal.focus-restore.test.tsx
import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { useState } from 'react';
import { Modal } from './Modal';

function TestHost() {
  const [open, setOpen] = useState(false);
  return (
    <>
      <button onClick={() => setOpen(true)}>開く</button>
      <Modal isOpen={open} onClose={() => setOpen(false)}>
        <button onClick={() => setOpen(false)}>閉じる</button>
      </Modal>
    </>
  );
}

describe('Modalフォーカス復元', () => {
  it('閉じたあと、開いた要素にフォーカスが戻る', async () => {
    const user = userEvent.setup();
    render(<TestHost />);
    const opener = screen.getByRole('button', { name: '開く' });
    opener.focus();
    await user.click(opener);

    await user.click(screen.getByRole('button', { name: '閉じる' }));

    expect(document.activeElement).toBe(opener);
  });
});
```

### パターン4: aria属性の動的な更新

状態変化に伴うaria属性の更新を確認します。

```tsx
// npm run test:run -- src/components/Accordion/Accordion.a11y.test.tsx
import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { Accordion } from './Accordion';

describe('Accordion aria属性の動的な更新', () => {
  it('ヘッダーをクリックすると展開状態になる', async () => {
    const user = userEvent.setup();
    render(<Accordion title="詳細">本文</Accordion>);
    const trigger = screen.getByRole('button', { name: '詳細' });

    await user.click(trigger);

    expect(trigger).toHaveAttribute('aria-expanded', 'true');
  });

  it('展開中にヘッダーをクリックすると折りたたみ状態になる', async () => {
    const user = userEvent.setup();
    render(<Accordion title="詳細">本文</Accordion>);
    const trigger = screen.getByRole('button', { name: '詳細' });
    await user.click(trigger);

    await user.click(trigger);

    expect(trigger).toHaveAttribute('aria-expanded', 'false');
  });
});
```

### パターン5: ライブリージョン

通知・エラー発火時に`role="status"` / `role="alert"`を持つ要素が出現することを確認します。

```tsx
// npm run test:run -- src/components/Toast/Toast.a11y.test.tsx
import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { ToastProvider, useToast } from './Toast';

function TestHost() {
  const { showToast } = useToast();
  return <button onClick={() => showToast('保存しました')}>保存</button>;
}

describe('Toastライブリージョン', () => {
  it('保存ボタンを押すと通知が表示される', async () => {
    const user = userEvent.setup();
    render(
      <ToastProvider>
        <TestHost />
      </ToastProvider>
    );

    await user.click(screen.getByRole('button', { name: '保存' }));

    expect(screen.getByRole('status')).toHaveTextContent('保存しました');
  });
});
```

エラー系（`role="alert"`）は緊急度の高い通知で使います。プロジェクトの設計方針に合わせて使い分けます。

### パターン6: バリデーションエラーのaria属性設定

バリデーションエラー発生時に、フィールド自体と支援技術への通知が正しく設定されることを確認します。自動ツール（axe等）が検出できない「フィールドとエラーメッセージの紐づけ」の動的検証を担います。

```tsx
// VERIFY:meta
//   対象機能:           ログインフォームのバリデーションエラー通知
//   想定ユーザー:       スクリーンリーダーを使用するユーザー
//   目的:               エラー内容がフォーカスを移動しなくても支援技術に伝わる
//   前提条件:           none
//   起こり得る外部条件: none
//   テスト範囲外:       実スクリーンリーダーでの読み上げ順序 (VERIFY:manualで扱う)
//   最終レビュー日:     2026-05-13

// npm run test:run -- src/components/LoginForm/LoginForm.a11y.test.tsx
import { describe, it, expect, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { LoginForm } from './LoginForm';

describe('LoginFormバリデーションエラーのaria属性設定', () => {
  it('必須項目が空のまま送信するとエラー内容が支援技術に伝わる状態になる', async () => {
    const user = userEvent.setup();
    render(<LoginForm onSubmit={vi.fn()} />);

    await user.click(screen.getByRole('button', { name: 'ログイン' }));

    const emailInput = screen.getByLabelText('メールアドレス');
    const describedById = emailInput.getAttribute('aria-describedby');
    expect(emailInput).toHaveAttribute('aria-invalid', 'true');
    expect(describedById).not.toBeNull();
    expect(document.getElementById(describedById!)).toHaveTextContent('メールアドレスを入力してください');
  });

  it('送信するとエラーメッセージが即時に通知される', async () => {
    const user = userEvent.setup();
    render(<LoginForm onSubmit={vi.fn()} />);

    await user.click(screen.getByRole('button', { name: 'ログイン' }));

    expect(screen.getByRole('alert')).toHaveTextContent('メールアドレスを入力してください');
  });

  it('エラーを修正するとフィールドのエラー状態が解除される', async () => {
    const user = userEvent.setup();
    render(<LoginForm onSubmit={vi.fn()} />);
    await user.click(screen.getByRole('button', { name: 'ログイン' }));
    const emailInput = screen.getByLabelText('メールアドレス');

    await user.type(emailInput, 'a@example.com');

    expect(emailInput).not.toHaveAttribute('aria-invalid', 'true');
  });
});
```

確認すべきチェックポイントは次の通りです。

- `aria-invalid="true"`はエラー発生後に動的に設定されるか（静的に`false`をハードコードしていないか）
- `aria-describedby`の値がエラーメッセージ要素の`id`と一致しているか
- 複数フィールドが同時にエラーになる場合、各フィールドが個別のエラーメッセージを`aria-describedby`で参照しているか

## e2eと組み合わせるケース

複数ページにまたがるa11y検証（ページ間のフォーカス移動、SPAナビゲーション後のフォーカス位置）はcomponent testでは完結しません。`e2e-test-patterns.md`のPlaywrightベース構成と組み合わせます。

```ts
// e2eでフォーカス位置を確認する例
import { test, expect } from '@playwright/test';

test('SPA遷移後にメインコンテンツのh1へフォーカスが移る', async ({ page }) => {
  await page.goto('/');
  await page.getByRole('link', { name: '設定' }).click();

  const focused = await page.evaluate(() => document.activeElement?.tagName);
  expect(focused).toBe('H1');
});
```

ただしe2eにすべてのa11y検証を寄せると不安定になりやすいです。component testで書ける範囲はcomponent testに寄せます。

## 手動検証に寄せる項目（参考）

以下は`VERIFY:manual`として残します。component testでは検証しません。

- 実スクリーンリーダーでの読み上げの意味的自然さ
- 読み上げ順序の認知的な自然さ
- 多言語環境での読み上げ
- 支援技術と実OSの組み合わせ依存の問題

```tsx
// VERIFY:manual
//   検証内容:           VoiceOverでのアコーディオン読み上げ
//   検証手順:           1. macOSでVoiceOver有効化 (Cmd+F5) 2. Accordion要素にフォーカス 3. VO+Spaceで開閉 4. 状態が読み上げられる
//   合格基準:           「詳細、折りたたみ、ボタン」→「詳細、展開、ボタン」のように状態が読まれる
//   手動で確認する理由: 自動テストでは支援技術の実挙動を再現できない
//   実施タイミング:     リリース前 / 該当コンポーネントの構造変更時
```

スクリーンリーダー読み上げを自動化したい場合は`@guidepup/playwright`等のツールがありますが、CI環境構築への依存が大きいため、まずはcomponent testでのaria属性検証 + 手動SR確認の二段構えを推奨します。

## テスト実行

```bash
npm run test:run -- src/components/Xxx/Xxx.a11y.test.tsx
```

## 設計改善のチェックリスト

### チェック1: クリックハンドラーだけ持っていないか

`<div onClick={...}>`のようにdivでクリックを受けると、キーボードで操作できません。`<button>`を使うか、`role="button"` + `onKeyDown`でキーボード対応します。

### チェック2: aria属性をハードコードしていないか

`aria-expanded="false"`をJSXに直書きすると状態と乖離します。`aria-expanded={isOpen}`のようにstateをbindします。

### チェック3: tabindexを多用していないか

`tabindex="-1"`以外（とくに正の値）はa11yを壊しやすいです。原則0 / -1だけを使い、DOM順序でフォーカス順を制御します。

### チェック4: フォーカススタイルが消えていないか

`outline: none`を無条件に当てていないか確認します。キーボード操作時のフォーカスインジケーターが見えないと操作不能になります。`:focus-visible`を使います。

### チェック5: モーダルで`inert`または同等の処理がされているか

モーダルが開いている間、背景の要素はTabで到達できないようにします。`inert`属性 / `aria-hidden` / `aria-modal`の設定漏れがないか確認します。

### チェック6: フォームエラーで`aria-invalid`と`aria-describedby`を設定しているか

エラー時に`aria-invalid="true"`を付与しないと、スクリーンリーダーはフィールドがエラー状態であることを認識できません。また`aria-describedby`でエラーメッセージ要素の`id`を参照しないと、フォーカスを移動しなければエラー内容を把握できません。エラーメッセージ側は`role="alert"`を持たせて即時読み上げを促します。
