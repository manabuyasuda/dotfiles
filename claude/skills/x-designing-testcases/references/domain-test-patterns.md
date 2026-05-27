# ドメインロジックのテストパターン

`test-target-classification.md`で「業務ルールを持つ純粋関数」と判別された場合に読みます。Vitestを使用することを前提とします。

## 適用条件

- `domain/`配下のファイルに適用します
- Reactに依存しない純粋TypeScriptが対象です
- 業務のルール・制約・変換を実装しているものが対象です（判定 / 制約 / 変換）

## パターン判別

対象ファイルをReadし、含まれる関数・型から該当パターンを決めます。複数該当する場合はすべて適用します。

| パターン | 適用条件 | テストの観点 |
|---|---|---|
| 値オブジェクト | branded type（`Symbol` brand）+ factory関数 | 有効値・境界値（min/maxの内外）・無効値（範囲外・小数・負数） |
| Result型バリデーション | `createXxx(value: string): Result<T, E>`形式の関数 | ok()を返すケース全列挙・err()を返すケース（空文字・未定義値・大文字キーなど） |
| 比較・ソート | `compareXxx(a, b): number`または`getAllXxxList()` | 大小関係・同値・期待するソート順序 |
| 判定関数 | `canXxx(...): boolean`または`isXxx(...): boolean`形式 | trueになる引数・falseになる引数をテーブル形式で網羅 |
| exhaustiveness check | `a satisfies never`を含むswitch/if | 全unionブランチを個別にテストケースで通過させる |
| const型オブジェクト | `as const satisfies Record<...>` + `getXxxLabel`等のgetter関数 | 全列挙値のgetter結果を`it.each`で網羅 |
| 状態遷移 | `transition(status, action): Status`のような状態×アクション→状態の変換 | 許容する遷移・許容しない遷移をテーブル形式で網羅 |
| Adapter | APIレスポンスをドメインモデルに変換する純粋関数（`toXxx(response)`） | 正常変換・未知値のエラー・各フィールドの変換を確認 |

## 共通ルール

- ファイル先頭に`VERIFY:meta`を必ず追加します（仕様は`verify-comment-spec.md`）
- 2行目にテスト実行コマンドをコメントで記載します（例: `// npm run test:run -- src/features/{feature}/domain/xxx.test.ts`）
- importは`from 'vitest'`と対象ファイルからの相対importのみにします
- `describe`でグループ化し、`it`で個別ケースを記述します
- テストの説明（`describe` / `it`の文字列）は日本語で書きます
- 同じ構造のケースが3つ以上続く場合は`it.each`でテーブルにまとめます
- neverthrowのResult型は`isOk()`で分岐した後、`result.value` / `result.error`に直接アクセスできます。`_unsafeUnwrap()`は型安全を捨てて強制取り出しするメソッドのため、アサーション目的でのみ使います。通常の値取り出しには使いません

## ファイル配置と命名

```
src/features/{feature}/domain/
├── xxx.ts
└── xxx.test.ts   ← ここに配置
```

## 各パターンのテンプレート

### パターン1: 値オブジェクト

境界値のケースが多い場合は`it.each`でテーブルにまとめます。

```ts
// VERIFY:meta
//   対象機能:           馬番の制約定義
//   想定ユーザー:       このモジュールを呼び出すコード
//   目的:               馬番として有効な値（1〜99の整数）だけを通す
//   前提条件:           none
//   起こり得る外部条件: none
//   テスト範囲外:       UIでの馬番表示
//   最終レビュー日:     2026-05-13

// npm run test:run -- src/features/{feature}/domain/horse-number.test.ts
import { describe, it, expect } from 'vitest';
import { createHorseNumber } from './horse-number';

describe('createHorseNumber', () => {
  describe('有効な値', () => {
    it('範囲内の整数を有効な値として受け付ける', () => {
      const result = createHorseNumber(5);

      expect(result.isOk()).toBe(true);
      expect(result._unsafeUnwrap()).toBe(5);
    });
  });

  describe('境界値', () => {
    it.each([
      { input: 1,   valid: true,  desc: '最小値は受け付ける' },
      { input: 99,  valid: true,  desc: '最大値は受け付ける' },
      { input: 0,   valid: false, desc: '最小値を下回る値は受け付けない' },
      { input: 100, valid: false, desc: '最大値を超えた値は受け付けない' },
    ])('$desc', ({ input, valid }) => {
      expect(createHorseNumber(input).isOk()).toBe(valid);
    });
  });

  describe('無効な値', () => {
    it.each([1.5, -1])('小数・負数は受け付けない: %d', (input) => {
      expect(createHorseNumber(input).isErr()).toBe(true);
    });
  });
});
```

### パターン2: Result型バリデーション

```ts
// npm run test:run -- src/features/{feature}/domain/ticket-type.test.ts
import { describe, it, expect } from 'vitest';
import { createTicketType, TICKET_TYPES } from './ticket-type';

describe('createTicketType', () => {
  describe('有効な値のケース', () => {
    it('"tanshou"を有効な券種として受け付ける', () => {
      const result = createTicketType('tanshou');

      expect(result.isOk()).toBe(true);
    });

    it.each(Object.values(TICKET_TYPES))('"%s"を有効な券種として受け付ける', (value) => {
      expect(createTicketType(value).isOk()).toBe(true);
    });
  });

  describe('無効な値のケース', () => {
    it.each(['unknown', '', 'UPPERCASE_KEY'])('無効な値を受け付けない: "%s"', (input) => {
      const result = createTicketType(input);

      expect(result.isErr()).toBe(true);
      expect(result._unsafeUnwrapErr().type).toBe('InvalidTicketType');
    });
  });
});
```

### パターン3: 比較・ソート

```ts
// npm run test:run -- src/features/{feature}/domain/xxx.test.ts
import { describe, it, expect } from 'vitest';
import { compareTicketType, getAllTicketTypes } from './ticket-type';

describe('compareTicketType', () => {
  it.each([
    { a: 'tanshou', b: 'fukushou', sign: -1, label: 'tanshouはfukushouより前' },
    { a: 'fukushou', b: 'tanshou', sign:  1, label: 'fukushouはtanshouより後' },
    { a: 'tanshou', b: 'tanshou', sign:  0, label: '同じ値のとき順序は同じ（0）' },
  ] as const)('$label', ({ a, b, sign }) => {
    expect(Math.sign(compareTicketType(a, b))).toBe(sign);
  });
});

describe('getAllTicketTypes', () => {
  it('期待する順序で返す', () => {
    expect(getAllTicketTypes()).toEqual(['tanshou', 'fukushou', /* 実際の順序 */]);
  });
});
```

`Math.sign()`で正負を正規化します（絶対値は実装依存なので検証しません）。

### パターン4: 判定関数

`canXxx` / `isXxx`のようにbooleanを返す純粋関数です。`it.each`でtrue / falseを返す両パターンを網羅します。

```ts
// npm run test:run -- src/features/{feature}/domain/can-access-tipster.test.ts
import { describe, it, expect } from 'vitest';
import { canAccessTipster } from './can-access-tipster';

describe('canAccessTipster', () => {
  it.each([
    { isFinished: true,  permission: undefined,           expected: true,  desc: 'レース終了後は常に閲覧できる' },
    { isFinished: false, permission: { isDenied: false }, expected: true,  desc: '権限があり・レース進行中は閲覧できる' },
    { isFinished: false, permission: undefined,           expected: false, desc: '権限情報がない場合は閲覧できない' },
    { isFinished: false, permission: { isDenied: true },  expected: false, desc: '権限が拒否されている場合は閲覧できない' },
  ])('$desc', ({ isFinished, permission, expected }) => {
    expect(canAccessTipster(isFinished, permission)).toBe(expected);
  });
});
```

### パターン5: exhaustiveness check

`satisfies never`はTypeScriptコンパイラが未処理のunionブランチを検知するための構文です。新しい値を追加したとき処理を忘れるとコンパイルエラーになります。テストより型が担保するパターンなので、コンパイルが通ることを本質的な検証とします。

ランタイムテストでは各ブランチが正しく処理されることだけを確認します。

```ts
// npm run test:run -- src/features/{feature}/domain/xxx.test.ts
import { describe, it, expect } from 'vitest';
import { renderTicketType } from './render-ticket-type';

describe('renderTicketType', () => {
  it.each([
    'tanshou', 'fukushou', 'umaren', /* 全 union ブランチ */
  ] as const)('%sを処理できる', (type) => {
    expect(renderTicketType(type)).toBeDefined();
  });
});
```

### パターン6: const型オブジェクト

`as const satisfies Record<SomeType, ...>`で定義されたメタデータオブジェクトと、そこから値を取り出すgetter関数のテストです。全列挙値を`it.each`で網羅することで、新しい値を追加したときに表示名の追加漏れをテストレベルでも検出できます。

全列挙値と期待値が明確な場合は、次のパターンで列挙します。

```ts
// npm run test:run -- src/features/{feature}/domain/xxx.test.ts
import { describe, it, expect } from 'vitest';
import { TICKET_TYPES, getTicketTypeLabel } from './ticket-type';

describe('getTicketTypeLabel', () => {
  it.each([
    { type: TICKET_TYPES.TANSHOU,  expected: '単勝' },
    { type: TICKET_TYPES.FUKUSHOU, expected: '複勝' },
    { type: TICKET_TYPES.UMAREN,   expected: '馬連' },
    // 全列挙値分のケース
  ])('"$type"の表示名は"$expected"になる', ({ type, expected }) => {
    expect(getTicketTypeLabel(type)).toBe(expected);
  });
});
```

全列挙値の網羅だけ確認したい場合（具体的な表示名のアサートは別途行う場合）は、次のようにします。

```ts
describe('getTicketTypeLabel', () => {
  it.each(Object.values(TICKET_TYPES))('%sの表示名が定義されている', (type) => {
    expect(getTicketTypeLabel(type)).toBeDefined();
    expect(typeof getTicketTypeLabel(type)).toBe('string');
  });
});
```

### パターン7: 状態遷移

許容する遷移と許容しない遷移を両方テーブル形式で網羅します。

```ts
// npm run test:run -- src/features/{feature}/domain/race-status.test.ts
import { describe, it, expect } from 'vitest';
import { canAdvance, transition } from './race-status';

describe('canAdvance', () => {
  describe('許可される状態', () => {
    it.each(['scheduled', 'inProgress'] as const)(
      '%s状態のとき許可される',
      (status) => {
        expect(canAdvance(status)).toBe(true);
      },
    );
  });

  describe('許可されない状態', () => {
    it.each(['finished', 'cancelled'] as const)(
      '%s状態のとき許可されない',
      (status) => {
        expect(canAdvance(status)).toBe(false);
      },
    );
  });
});

describe('transition', () => {
  describe('許容する遷移', () => {
    it.each([
      { from: 'scheduled',  action: 'start',    to: 'inProgress' },
      { from: 'inProgress', action: 'finish',   to: 'finished'   },
      { from: 'scheduled',  action: 'cancel',   to: 'cancelled'  },
    ] as const)('$from状態で$actionすると$toに遷移する', ({ from, action, to }) => {
      expect(transition(from, action)).toBe(to);
    });
  });

  describe('許容しない遷移', () => {
    it.each([
      { from: 'finished',  action: 'start'  },
      { from: 'cancelled', action: 'finish' },
    ] as const)('$from + $actionはエラーになる', ({ from, action }) => {
      expect(() => transition(from, action)).toThrow();
    });
  });
});
```

### パターン8: Adapter

APIレスポンスをドメインモデルに変換する純粋関数のテストです。正常変換・対応していない値のエラー・各フィールドの変換を確認します。

```ts
// npm run test:run -- src/features/{feature}/domain/to-race.test.ts
import { describe, it, expect } from 'vitest';
import { toRace } from './to-race';
import type { ApiRaceResponse } from '../api/types';

describe('toRace', () => {
  it('APIレスポンスをドメインモデルに変換できる', () => {
    const response: ApiRaceResponse = {
      race_id: 'r123',
      name: '東京優駿',
      status_code: 'IP',
      // 正常なレスポンスデータ
    };

    const result = toRace(response);

    expect(result.id).toBe('r123');
    expect(result.name).toBe('東京優駿');
    expect(result.status).toBe('inProgress');
  });

  it('対応していないステータスを含む場合はエラーになる', () => {
    const response = {
      race_id: 'r123',
      name: '東京優駿',
      status_code: 'UNKNOWN',
    } as ApiRaceResponse;

    expect(() => toRace(response)).toThrow();
  });

  it.each([
    { code: 'SC', expected: 'scheduled' },
    { code: 'IP', expected: 'inProgress' },
    { code: 'FN', expected: 'finished' },
    { code: 'CN', expected: 'cancelled' },
  ])('APIコード"$code"は"$expected"に変換される', ({ code, expected }) => {
    const response = { race_id: 'r', name: 'n', status_code: code } as ApiRaceResponse;

    const result = toRace(response);

    expect(result.status).toBe(expected);
  });
});
```

## テスト実行

```bash
npm run test:run -- src/features/{feature}/domain/xxx.test.ts
```

エラーがあれば修正します。Vitestが未導入の場合はプロジェクトのセットアップドキュメントを参照してください。

## 設計改善のチェックリスト

テストを書く過程でコードの設計上の問題が浮かびやすいです。以下のチェックリストで対象ファイルを評価し、気づいた改善点をユーザーに提案します。修正は提案のみにとどめ、実装はユーザーの判断に委ねます。

### チェック1: 副作用・非決定的依存が混入していないか

`Date.now()` / `Math.random()` / `fetch()`がドメイン関数の内部で直接使われている場合、引数として外から渡す設計に変えることでテスト時に値を固定できます。

```ts
// NG: 関数内で現在時刻を取得している（テストから制御できない）
export const isExpired = (expiresAt: number) => Date.now() > expiresAt;

// OK: 比較する時刻を引数で受け取る（テストで任意の時刻を渡せる）
export const isExpired = (expiresAt: number, now: number) => now > expiresAt;
```

### チェック2: `validate`ではなく`parse`になっているか

`boolean`を返す検証関数は、呼び出し側が「検証済みかどうか」を型から判断できません。`Result<T, E>`を返すfactory関数に変えると、検証後の値が型安全に扱えます。

```ts
import { Result, err, ok } from 'neverthrow';

// 1. エラー型には type フィールドを持たせる（テストで種別を確認できるように）
export type HorseNumberError = {
  type: 'InvalidHorseNumber';
  message: string;
};

// 2. booleanを返すvalidateではなく、Resultを返すparse（create）関数にする
export const createHorseNumber = (n: number): Result<HorseNumber, HorseNumberError> => {
  if (n < MIN_HORSE_NUMBER || n > MAX_HORSE_NUMBER) {
    return err({ type: 'InvalidHorseNumber', message: `...: ${n}` });
  }
  return ok(n as HorseNumber);
};
```

### チェック3: エラー型に`type`フィールドがあるか

`err()`の引数に`type`フィールドがないと、テストでエラー種別を判別できません。

```ts
// NG: エラーがただの文字列
return err('無効な馬番');

// OK: type フィールドで種別を識別できる
return err({ type: 'InvalidHorseNumber', message: '...' });
```

### チェック4: テスト名が振る舞いを記述しているか（自己確認）

生成したテストを見直し、以下に該当する`it`文がある場合はリネームを提案します。

- `createXxx のテスト` → NG（メソッド名をそのまま書いている）
- `isOk が true を返す` → NG（実装の詳細）
- `有効な範囲外の値を受け付けない` → OK（条件と結果を記述している）

### チェック5: 1つの関数が複数の責務を持っていないか

テストケースを書く中で「この関数はAとBの2つをテストしている」と感じたら、責務の分離を提案します。値の検証と変換が同じ関数に混在しているケースがその典型例です。

### チェック6: `satisfies never`を使えるユニオン処理があるか

union型の全ブランチを網羅する`switch` / `if`があるのにexhaustiveness checkがない場合、`a satisfies never`の追加を提案します。新しい値がunionへ追加されたとき、コンパイルエラーで検出できます。
