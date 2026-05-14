# Visualテストのパターン

`test-target-classification.md`で「視覚的な状態の差」と判別された場合に読みます。Storybook + `@storybook/test-runner` + Playwrightをデフォルトとして使います。

プロジェクトに`.storybook`ディレクトリと`@storybook/test-runner`の設定がなければ、プロジェクトの構成（Chromatic / Visual Tests addon / Percy / 自前Playwrightスクリプト等）を確認して読み替えてください。

## 適用条件

- コンポーネントの視覚的な差分を退行検知する
- 状態バリエーション（loading / empty / success / error / 大量データ等）を視覚的に固定する
- レスポンシブ・ダークモード・ハイコントラスト等の表示差を確認する

CSSの実値（特定の`getComputedStyle`の値）の確認はAgentic Verificationに寄せます（`VERIFY:agentic`コメントとして併記）。visual regressionは誤差吸収のため、ピクセル単位の数値は見えません。

## パターン判別

| パターン | 適用条件 | テストの観点 |
|---|---|---|
| 状態バリエーション | コンポーネントが複数の状態を持つ | loading / empty / success / error / 各状態のスクショ |
| デバイス多様性 | レスポンシブが必要 | 複数viewportでのスクショ |
| テーマ・モード差 | ダークモード / RTL / prefers-reduced-motion | 各モードでのスクショ |
| 動的要素の安定化 | 日時表示・アニメーション・乱数を含む | フィクスチャ固定でスナップショットを安定させる |

## 共通ルール

- Storyファイル先頭に`VERIFY:meta`を必ず追加します
- 1 Story = 1状態にします。組み合わせはStoryを分けて表現します
- 日時・乱数・アニメーションはStory内で必ず固定します
- APIレスポンスはMSWで固定します
- スクリーンショット差分の閾値はvisual regressionツールのデフォルトに任せます（自前で`threshold`を緩めません）

## ファイル配置と命名

```
src/components/UserList/
├── UserList.tsx
└── UserList.stories.tsx
```

## 各パターンのテンプレート

### パターン1: 状態バリエーション

```tsx
// VERIFY:meta
//   対象機能:           ユーザーリストの状態別表示
//   想定ユーザー:       エンドユーザー
//   目的:               loading / empty / success / errorの各状態が視覚的に区別できる
//   前提条件:           none
//   起こり得る外部条件: cond.external (APIレスポンス揺れ)
//   テスト範囲外:       実APIとの結合 (e2eで扱う) / a11y属性 (a11yで扱う)
//   最終レビュー日:     2026-05-13

// src/components/UserList/UserList.stories.tsx
import type { Meta, StoryObj } from '@storybook/react';
import { UserList } from './UserList';

const meta: Meta<typeof UserList> = {
  component: UserList,
  parameters: {
    layout: 'centered',
  },
};
export default meta;

type Story = StoryObj<typeof UserList>;

export const Loading: Story = {
  args: { status: 'loading', users: [] },
};

export const Empty: Story = {
  args: { status: 'success', users: [] },
};

export const Success: Story = {
  args: {
    status: 'success',
    users: [
      { id: '1', name: 'User 1' },
      { id: '2', name: 'User 2' },
    ],
  },
};

export const Error: Story = {
  args: { status: 'error', users: [], error: '取得に失敗しました' },
};

export const LargeDataSet: Story = {
  args: {
    status: 'success',
    users: Array.from({ length: 100 }, (_, i) => ({
      id: String(i),
      name: `User ${i}`,
    })),
  },
};
```

### パターン2: デバイス多様性

`parameters.viewport`で複数viewportを1 Storyから生成します。

```tsx
// src/components/Header/Header.stories.tsx
import type { Meta, StoryObj } from '@storybook/react';
import { Header } from './Header';

const meta: Meta<typeof Header> = {
  component: Header,
};
export default meta;

type Story = StoryObj<typeof Header>;

export const Mobile: Story = {
  parameters: {
    viewport: { defaultViewport: 'mobile1' },
  },
};

export const Tablet: Story = {
  parameters: {
    viewport: { defaultViewport: 'tablet' },
  },
};

export const Desktop: Story = {
  parameters: {
    viewport: { defaultViewport: 'desktop' },
  },
};
```

Chromaticを使う場合は、`parameters.chromatic.viewports`を指定すると1 Story内で複数viewportを撮影できます。

```tsx
export const AllViewports: Story = {
  parameters: {
    chromatic: { viewports: [375, 768, 1280] },
  },
};
```

### パターン3: テーマ・モード差

```tsx
// src/components/Card/Card.stories.tsx
import type { Meta, StoryObj } from '@storybook/react';
import { Card } from './Card';

const meta: Meta<typeof Card> = {
  component: Card,
};
export default meta;

type Story = StoryObj<typeof Card>;

export const Light: Story = {
  parameters: { theme: 'light' },
};

export const Dark: Story = {
  parameters: { theme: 'dark' },
};

export const HighContrast: Story = {
  parameters: { theme: 'high-contrast' },
};

export const ReducedMotion: Story = {
  parameters: {
    pseudo: { hover: true },
    cssCustomProperties: { '--prefers-reduced-motion': 'reduce' },
  },
};
```

テーマ切替は`decorators`かStorybookのTheme addonに従います。各プロジェクトの設定に合わせて読み替えてください。

### パターン4: 動的要素の安定化

日時・アニメーション・乱数は必ず固定します。固定しないとvisual regressionが毎回失敗します。

```tsx
// src/components/Notification/Notification.stories.tsx
import type { Meta, StoryObj } from '@storybook/react';
import { Notification } from './Notification';

const meta: Meta<typeof Notification> = {
  component: Notification,
  parameters: {
    // アニメーション無効化
    chromatic: { pauseAnimationAtEnd: true },
    // 日時固定
    mockdate: new Date('2026-01-15T10:00:00Z'),
  },
};
export default meta;

type Story = StoryObj<typeof Notification>;

export const Default: Story = {
  args: {
    receivedAt: new Date('2026-01-15T09:30:00Z'),
    message: '新しいコメントがあります',
  },
};
```

APIレスポンスを含む場合はMSWを使います。

```tsx
import { http, HttpResponse } from 'msw';

export const WithApi: Story = {
  parameters: {
    msw: {
      handlers: [
        http.get('/api/users', () =>
          HttpResponse.json([{ id: '1', name: 'Alice' }])
        ),
      ],
    },
  },
};
```

## test-runnerの設定

`@storybook/test-runner`の`play`関数で各Storyの振る舞いを確認しつつ、Playwrightのスクリーンショット機能でビジュアル差分を取ります。

```ts
// .storybook/test-runner.ts
import type { TestRunnerConfig } from '@storybook/test-runner';

const config: TestRunnerConfig = {
  async postVisit(page, context) {
    const image = await page.screenshot();
    expect(image).toMatchSnapshot({
      identifier: context.id,
    });
  },
};

export default config;
```

## 実行

```bash
npm run test-storybook
```

specific storiesのみ実行する場合:

```bash
npm run test-storybook -- --testNamePattern UserList
```

## CSS実値の検証はVERIFY:agenticに寄せる

visual regressionは誤差吸収のため実値が見えません。`getComputedStyle()`での実値確認はAgentic検証として併記します。

```tsx
// VERIFY:agentic
//   検証内容:               border-radiusがdesign token (--radius-full) から適用されている
//   検証手順:               1. Storybookを起動 2. ブラウザMCPでUserAvatarのStoryを開く 3. avatar要素を取得 4. getComputedStyle(el).borderRadiusを取得
//   合格基準:               9999px (or tokenと同じ計算値)
//   自動テスト化しない理由: visual regressionは誤差吸収のため数値が見えない
//   自動テスト化する条件:   token経由でないハードコード値が再発したら、CSS実値検証用e2eに昇格
```

## 設計改善のチェックリスト

### チェック1: 状態の組み合わせをStoryにまとめすぎていない

1 Storyに複数状態を詰め込むと、差分が出たときどの状態の問題かわかりません。1 Story 1状態が原則です。

### チェック2: 動的要素が固定されているか

日時・乱数・アニメーション・APIレスポンスが毎回違うと差分が出続けます。`parameters.mockdate`、MSW、`pauseAnimationAtEnd`で固定します。

### チェック3: viewport設定が一貫しているか

プロジェクト内でviewportの指定方法がStoryごとに違うと管理しにくいです。`.storybook/preview.ts`で共通viewportを定義します。

### チェック4: 差分閾値を緩めていないか

差分が出るからといってthresholdを緩めると、退行を見逃す原因になります。差分の原因（動的要素・フォントローディング・アニメーション）を取り除く方向で解決します。

### チェック5: visual regressionでa11yを検証しようとしていない

色のコントラスト等はaxe / markuplintで静的に検出します。visualは「見た目が変わっていないこと」だけを担保します。
