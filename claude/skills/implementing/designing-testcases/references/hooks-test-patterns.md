# React hooksのテストパターン

`test-target-classification.md`で「React hooks」と判別された場合に読みます。Vitest + `@testing-library/react`の`renderHook`を使用することを前提とします。

## 適用条件

- `hooks/`配下のファイルに適用します
- Reactに依存します（`useState` / `useEffect` / `useContext` / `useSyncExternalStore`等を使います）
- 副作用・状態管理が主な責務です（外部API呼び出し / localStorage / subscription / カスタムreducer等）

## パターン判別

| パターン | 適用条件 | テストの観点 |
|---|---|---|
| 状態管理 | `useState` / `useReducer`ベースの状態を返す | 初期値・状態遷移・derived state |
| 副作用 | `useEffect` / `useLayoutEffect`で副作用を持つ | 依存配列・cleanup・unmount時の挙動 |
| データ取得 | React Query / SWR / 自前のfetch hook | loading / success / errorの3状態、再取得トリガー |
| 外部購読 | `useSyncExternalStore` / subscription系 | 購読開始・更新・解除 |
| DOM参照 | `useRef` + `useEffect`でDOM操作 | マウント後の参照、unmount時のcleanup |

## 共通ルール

- ファイル先頭に`VERIFY:meta`を必ず追加します
- 2行目にテスト実行コマンドをコメントで記載します
- `renderHook`を使います。手動で`<TestComponent>`を書きません
- 非同期は`waitFor`で待ちます。`setTimeout`でのスリープは使いません
- `act()`でラップが必要な操作は明示的に`act(() => ...)`で囲みます
- cleanupは`afterEach`で`cleanup()`を呼びます（Vitest設定で自動cleanupが有効ならスキップ可）

## ファイル配置と命名

```
src/hooks/
├── use-counter.ts
└── use-counter.test.ts
```

またはfeature内:

```
src/features/{feature}/hooks/
├── use-xxx.ts
└── use-xxx.test.ts
```

## 各パターンのテンプレート

### パターン1: 状態管理

```ts
// VERIFY:meta
//   対象機能:           カウンター状態の管理
//   想定ユーザー:       このフックを使うコンポーネント
//   目的:               増減操作を持つ数値状態を提供する
//   前提条件:           none
//   起こり得る外部条件: none
//   テスト範囲外:       UI表示
//   最終レビュー日:     2026-05-13

// npm run test:run -- src/hooks/use-counter.test.ts
import { describe, it, expect } from 'vitest';
import { renderHook, act } from '@testing-library/react';
import { useCounter } from './use-counter';

describe('useCounter', () => {
  describe('初期値', () => {
    it('指定した値を初期値として持つ', () => {
      const { result } = renderHook(() => useCounter(5));

      expect(result.current.count).toBe(5);
    });

    it('初期値を指定しない場合は0になる', () => {
      const { result } = renderHook(() => useCounter());

      expect(result.current.count).toBe(0);
    });
  });

  describe('状態遷移', () => {
    it('1増やすと値が1増える', () => {
      const { result } = renderHook(() => useCounter(0));

      act(() => result.current.increment());

      expect(result.current.count).toBe(1);
    });

    it('1減らすと値が1減る', () => {
      const { result } = renderHook(() => useCounter(5));

      act(() => result.current.decrement());

      expect(result.current.count).toBe(4);
    });

    it('リセットすると初期値に戻る', () => {
      const { result } = renderHook(() => useCounter(5));
      act(() => result.current.increment());

      act(() => result.current.reset());

      expect(result.current.count).toBe(5);
    });
  });
});
```

### パターン2: 副作用とcleanup

依存配列の変化とunmount時のcleanupを確認します。

```ts
// npm run test:run -- src/hooks/use-event-listener.test.ts
import { describe, it, expect, vi } from 'vitest';
import { renderHook } from '@testing-library/react';
import { useEventListener } from './use-event-listener';

describe('useEventListener', () => {
  it('使い始めるとイベントリスナーを登録する', () => {
    const addSpy = vi.spyOn(window, 'addEventListener');

    renderHook(() => useEventListener('resize', () => {}));

    expect(addSpy).toHaveBeenCalledWith('resize', expect.any(Function));
    addSpy.mockRestore();
  });

  it('コンポーネントを取り外すとリスナーが解除される', () => {
    const removeSpy = vi.spyOn(window, 'removeEventListener');
    const { unmount } = renderHook(() => useEventListener('resize', () => {}));

    unmount();

    expect(removeSpy).toHaveBeenCalledWith('resize', expect.any(Function));
    removeSpy.mockRestore();
  });

  it('コールバックが変わると新しいコールバックが呼ばれる', () => {
    const handler1 = vi.fn();
    const handler2 = vi.fn();
    const { rerender } = renderHook(
      ({ h }) => useEventListener('resize', h),
      { initialProps: { h: handler1 } }
    );
    rerender({ h: handler2 });

    window.dispatchEvent(new Event('resize'));

    expect(handler2).toHaveBeenCalledTimes(1);
  });

  it('コールバックが変わっても古いコールバックは呼ばれない', () => {
    const handler1 = vi.fn();
    const handler2 = vi.fn();
    const { rerender } = renderHook(
      ({ h }) => useEventListener('resize', h),
      { initialProps: { h: handler1 } }
    );
    rerender({ h: handler2 });

    window.dispatchEvent(new Event('resize'));

    expect(handler1).not.toHaveBeenCalled();
  });
});
```

### パターン3: データ取得

3状態（loading / success / error）と再取得トリガーを網羅します。

```ts
// npm run test:run -- src/hooks/use-user.test.ts
import { describe, it, expect, beforeAll, afterAll, afterEach } from 'vitest';
import { renderHook, waitFor } from '@testing-library/react';
import { setupServer } from 'msw/node';
import { http, HttpResponse } from 'msw';
import { useUser } from './use-user';

const server = setupServer();
beforeAll(() => server.listen({ onUnhandledRequest: 'error' }));
afterEach(() => server.resetHandlers());
afterAll(() => server.close());

describe('useUser', () => {
  it('最初は読み込み中の状態になる', () => {
    server.use(
      http.get('/api/users/:id', () => HttpResponse.json({ id: '1', name: 'x' }))
    );

    const { result } = renderHook(() => useUser('1'));

    expect(result.current.status).toBe('loading');
  });

  it('取得成功時にデータを返す', async () => {
    server.use(
      http.get('/api/users/:id', () => HttpResponse.json({ id: '1', name: 'x' }))
    );

    const { result } = renderHook(() => useUser('1'));

    await waitFor(() => expect(result.current.status).toBe('success'));

    expect(result.current.data).toEqual({ id: '1', name: 'x' });
  });

  it('取得失敗時はエラーを返す', async () => {
    server.use(
      http.get('/api/users/:id', () => HttpResponse.error())
    );

    const { result } = renderHook(() => useUser('1'));

    await waitFor(() => expect(result.current.status).toBe('error'));

    expect(result.current.error?.message).toBeDefined();
  });

  it('引数が変わると再取得する', async () => {
    server.use(
      http.get('/api/users/1', () => HttpResponse.json({ id: '1', name: 'x' })),
      http.get('/api/users/2', () => HttpResponse.json({ id: '2', name: 'x' })),
    );
    const { rerender, result } = renderHook(({ id }) => useUser(id), {
      initialProps: { id: '1' },
    });

    await waitFor(() => expect(result.current.data?.id).toBe('1'));

    rerender({ id: '2' });

    await waitFor(() => expect(result.current.data?.id).toBe('2'));
  });
});
```

データ取得ライブラリ（React Query / SWR）を使う場合は、QueryClientProvider / SWRConfigをラップするwrapperを渡します。

```ts
const wrapper = ({ children }: { children: React.ReactNode }) => (
  <QueryClientProvider client={new QueryClient()}>{children}</QueryClientProvider>
);

const { result } = renderHook(() => useUser('1'), { wrapper });
```

### パターン4: 外部購読（useSyncExternalStore）

```ts
// npm run test:run -- src/hooks/use-online-status.test.ts
import { describe, it, expect, act } from 'vitest';
import { renderHook } from '@testing-library/react';
import { useOnlineStatus } from './use-online-status';

describe('useOnlineStatus', () => {
  it('初期状態はネットワーク接続状態を反映する', () => {
    Object.defineProperty(navigator, 'onLine', { value: true, configurable: true });
    const { result } = renderHook(() => useOnlineStatus());

    expect(result.current).toBe(true);
  });

  it('ネットワーク接続が復帰すると状態が更新される', () => {
    Object.defineProperty(navigator, 'onLine', { value: false, configurable: true });
    const { result } = renderHook(() => useOnlineStatus());

    act(() => {
      Object.defineProperty(navigator, 'onLine', { value: true, configurable: true });
      window.dispatchEvent(new Event('online'));
    });

    expect(result.current).toBe(true);
  });
});
```

### パターン5: DOM参照

```ts
// npm run test:run -- src/hooks/use-focus-on-mount.test.ts
import { describe, it, expect } from 'vitest';
import { renderHook } from '@testing-library/react';
import { useRef } from 'react';
import { useFocusOnMount } from './use-focus-on-mount';

describe('useFocusOnMount', () => {
  it('レンダリング後に指定した要素にフォーカスが当たる', () => {
    const input = document.createElement('input');
    document.body.appendChild(input);
    const ref = { current: input };

    renderHook(() => useFocusOnMount(ref as React.RefObject<HTMLInputElement>));

    expect(document.activeElement).toBe(input);
    input.remove();
  });
});
```

## SSR互換の確認

`window` / `document`を参照するhookはSSRで落ちないか確認します。Node環境（jsdomなし）でもimportできることを別途確認します。

```ts
// vitest.config.tsでenvironmentを 'node' に切り替えた別ファイルで実行する
// またはimport.meta.env.SSRで分岐して確認する

it('SSR環境でimportしてもエラーにならない', async () => {
  // node環境でのテスト想定
  const module = await import('./use-event-listener');
  expect(typeof module.useEventListener).toBe('function');
});
```

## テスト実行

```bash
npm run test:run -- src/hooks/xxx.test.ts
```

## 設計改善のチェックリスト

### チェック1: そもそもhookである必要があるか

hookが純粋計算しかしていないなら、`utils/`または`domain/`に切り出して通常の関数にする方がテストしやすいです。

### チェック2: 依存配列が網羅されているか

`useEffect` / `useMemo` / `useCallback`の依存配列に外部値が抜けていないか確認します。`eslint-plugin-react-hooks`の`exhaustive-deps`ルールで自動検出できます。

### チェック3: cleanupを返しているか

`useEffect`でsubscription / event listener / timerを作っているのにcleanupを返していなければ、メモリリークの原因になります。テストでunmount時の挙動を確認します。

### チェック4: 副作用がhookの外に出せないか

`Date.now()` / `Math.random()` / 環境変数参照などは引数で受け取る形にすると、テストで値を固定できます。

### チェック5: 過度な再レンダリングを引き起こしていないか

状態を返すオブジェクトを毎回新規生成していないか確認します。`useMemo` / `useCallback`で安定化を要することがあります（ただし過剰な最適化は避けます）。
