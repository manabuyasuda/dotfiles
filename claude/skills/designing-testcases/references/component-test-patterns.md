# Reactコンポーネントのテストパターン

`test-target-classification.md`で「Reactコンポーネント」と判別された場合に読みます。Vitest + `@testing-library/react` + `@testing-library/user-event`を使用することを前提とします。

## 適用条件

- `components/`配下のファイルに適用します
- Reactコンポーネント（レンダリングが主な責務）に適用します
- propsを受けてUIを出す構造が対象です

視覚的な差分の検証は`visual-test-patterns.md`、キーボード操作・フォーカス管理は`a11y-test-patterns.md`を併用します。

## パターン判別

| パターン | 適用条件 | テストの観点 |
|---|---|---|
| 表示の振る舞い | propsによって表示内容が変わる | 条件分岐ごとの表示の有無、テキスト・属性 |
| インタラクション | クリック・入力で状態が変わる | userEventでイベント発火、結果の表示変化 |
| コールバック発火 | onClick / onChange / onSubmit等を受け取る | コールバックが期待される引数で呼ばれる |
| エラーリカバリ | エラー状態のUIを持つ | エラー表示、再試行ボタン、入力保持 |
| 状態の組み合わせ | loading / empty / error / 大量データ | 各状態の表示 |

視覚的な差分の細かい検証（CSS実値、色、レイアウト）はこのパターンには含めません。`visual-test-patterns.md`に寄せます。

## 共通ルール

- ファイル先頭に`VERIFY:meta`を必ず追加します
- 2行目にテスト実行コマンドをコメントで記載します
- 要素の取得は`getByRole` > `getByLabelText` > `getByText`の優先順で行います。`getByTestId`は他で取れない場合の最終手段です
- 状態変化を伴うイベントは`userEvent`を使います。`fireEvent`は使いません（実際のユーザー操作と乖離するため）
- 非同期の表示変化は`findByXxx`または`waitFor`で待ちます
- 内部state、特定のCSSクラス、特定のDOM構造の細部にはアサートしません

## ファイル配置と命名

```
src/components/
└── Button/
    ├── Button.tsx
    └── Button.test.tsx
```

## 各パターンのテンプレート

### パターン1: 表示の振る舞い

```tsx
// VERIFY:meta
//   対象機能:           ボタンコンポーネント
//   想定ユーザー:       このコンポーネントを使う開発者と、それを通じたエンドユーザー
//   目的:               variantに応じた見た目とラベルを持つボタンを提供する
//   前提条件:           none
//   起こり得る外部条件: none
//   テスト範囲外:       色や余白の実値（visual-test-patternsで扱う）
//   最終レビュー日:     2026-05-13

// npm run test:run -- src/components/Button/Button.test.tsx
import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import { Button } from './Button';

describe('Button', () => {
  it('任意のラベルを表示できる', () => {
    render(<Button>送信</Button>);

    expect(screen.getByRole('button', { name: '送信' })).toBeInTheDocument();
  });

  it('無効化されているときは操作できない', () => {
    render(<Button disabled>送信</Button>);

    expect(screen.getByRole('button')).toBeDisabled();
  });

  it.each([
    { variant: 'primary'   },
    { variant: 'secondary' },
    { variant: 'danger'    },
  ] as const)('スタイル"$variant"でもボタンとして認識できる', ({ variant }) => {
    render(<Button variant={variant}>送信</Button>);

    expect(screen.getByRole('button')).toBeInTheDocument();
  });
});
```

### パターン2: インタラクション

```tsx
// npm run test:run -- src/components/SearchInput/SearchInput.test.tsx
import { describe, it, expect, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { SearchInput } from './SearchInput';

describe('SearchInput', () => {
  it('キーを押すたびに入力値が通知される', async () => {
    const user = userEvent.setup();
    const onChange = vi.fn();
    render(<SearchInput value="" onChange={onChange} />);

    const input = screen.getByRole('textbox', { name: '検索' });
    await user.type(input, 'hello');

    expect(onChange).toHaveBeenCalledTimes(5);
    expect(onChange).toHaveBeenLastCalledWith('hello');
  });

  it('クリアボタンで値が空になる', async () => {
    const user = userEvent.setup();
    const onChange = vi.fn();
    render(<SearchInput value="abc" onChange={onChange} />);

    await user.click(screen.getByRole('button', { name: 'クリア' }));

    expect(onChange).toHaveBeenLastCalledWith('');
  });
});
```

### パターン3: コールバック発火

`onClick` / `onSubmit`等のコールバックが期待される引数で呼ばれることを確認します。

```tsx
// npm run test:run -- src/components/LoginForm/LoginForm.test.tsx
import { describe, it, expect, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { LoginForm } from './LoginForm';

describe('LoginForm', () => {
  it('送信するとメールアドレスとパスワードが送信データに含まれる', async () => {
    const user = userEvent.setup();
    const onSubmit = vi.fn();
    render(<LoginForm onSubmit={onSubmit} />);
    await user.type(screen.getByLabelText('メールアドレス'), 'a@example.com');
    await user.type(screen.getByLabelText('パスワード'), 'secret');

    await user.click(screen.getByRole('button', { name: 'ログイン' }));

    expect(onSubmit).toHaveBeenCalledWith({
      email: 'a@example.com',
      password: 'secret',
    });
  });

  it('必須項目を入力しないまま送信してもフォームデータは送出されない', async () => {
    const user = userEvent.setup();
    const onSubmit = vi.fn();
    render(<LoginForm onSubmit={onSubmit} />);

    await user.click(screen.getByRole('button', { name: 'ログイン' }));

    expect(onSubmit).not.toHaveBeenCalled();
  });
});
```

### パターン4: エラーリカバリ

エラー状態の表示・再試行ボタン・入力保持を確認します。

```tsx
// npm run test:run -- src/components/UserProfileForm/UserProfileForm.test.tsx
import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { UserProfileForm } from './UserProfileForm';

describe('UserProfileForm', () => {
  describe('エラー状態の表示', () => {
    it('エラーが発生するとメッセージが表示される', () => {
      render(<UserProfileForm error="保存に失敗しました" />);

      expect(screen.getByRole('alert')).toHaveTextContent('保存に失敗しました');
    });

    it('エラーが起きても入力値が消えない', async () => {
      const user = userEvent.setup();
      const { rerender } = render(<UserProfileForm />);
      await user.type(screen.getByLabelText('氏名'), '山田太郎');

      rerender(<UserProfileForm error="保存に失敗しました" />);

      expect(screen.getByLabelText('氏名')).toHaveValue('山田太郎');
    });

    it('エラーが発生すると再試行ボタンが表示される', () => {
      render(<UserProfileForm error="保存に失敗しました" />);

      expect(screen.getByRole('button', { name: '再試行' })).toBeInTheDocument();
    });
  });
});
```

### パターン5: 状態の組み合わせ

loading / empty / error / 大量データの各状態を網羅します。視覚的な確認はvisualに寄せ、ここでは「どの要素が出るか」だけを確認します。

```tsx
// npm run test:run -- src/components/UserList/UserList.test.tsx
import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import { UserList } from './UserList';

describe('UserList', () => {
  it('読み込み中はスケルトンが表示される', () => {
    render(<UserList status="loading" users={[]} />);

    expect(screen.getByRole('status', { name: '読み込み中' })).toBeInTheDocument();
  });

  it('データが空のとき案内メッセージが表示される', () => {
    render(<UserList status="success" users={[]} />);

    expect(screen.getByText('ユーザーが見つかりません')).toBeInTheDocument();
  });

  it('取得成功時はユーザーが一覧表示される', () => {
    render(<UserList status="success" users={[
      { id: '1', name: 'x' },
      { id: '2', name: 'x' },
    ]} />);

    expect(screen.getAllByRole('listitem')).toHaveLength(2);
  });

  it('取得に失敗するとエラーと再試行ボタンが表示される', () => {
    render(<UserList status="error" users={[]} error="取得失敗" />);

    expect(screen.getByRole('alert')).toHaveTextContent('取得失敗');
    expect(screen.getByRole('button', { name: '再試行' })).toBeInTheDocument();
  });
});
```

## Provider / Contextを必要とするコンポーネント

QueryClientProvider / ThemeProvider / 自前Contextなどを必要とする場合は、test-utilsとして共通のwrapperを用意します。

```tsx
// src/test-utils/render.tsx
import { render as rtlRender } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';

export function render(ui: React.ReactElement) {
  const queryClient = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return rtlRender(
    <QueryClientProvider client={queryClient}>{ui}</QueryClientProvider>
  );
}
```

各テストでは`from '@/test-utils/render'`を使います。

## テスト実行

```bash
npm run test:run -- src/components/Xxx/Xxx.test.tsx
```

## 設計改善のチェックリスト

### チェック1: コンポーネントが複数の責務を持っていないか

1コンポーネントで「データ取得 + 状態管理 + 表示 + バリデーション」を全部やっているなら、責務分離を提案します。

### チェック2: 実装詳細にアサートしていないか

`container.querySelector('.xxx-class')`のようなCSSクラスへの依存、`expect(result.current.internalState)`のような内部stateへの依存は、リファクターで壊れます。`getByRole` / `getByLabelText`などユーザーから見える属性に寄せます。

### チェック3: テストが描画ライブラリの挙動を確認していないか

「`useState`でちゃんと再レンダリングされる」のようなReact自身のテストになっていないか確認します。

### チェック4: 1テストで複数の操作を連続させていないか

「フォームに入力 → 送信 → エラー表示 → 修正 → 再送信 → 成功」のような長いフローを1テストにまとめると失敗時の原因が分からなくなります。シナリオ単位で分割します。

### チェック5: a11yを`a11y-test-patterns.md`に分離する

キーボード操作、フォーカス管理、aria属性の動的変化は別ファイルに切り出すと整理しやすくなります。
