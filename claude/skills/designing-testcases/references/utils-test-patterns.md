# 汎用ユーティリティのテストパターン

`test-target-classification.md`で「汎用ユーティリティ関数」と判別された場合に読みます。Vitestを使用することを前提とします。

## 適用条件

- `utils/`配下のファイルに適用します
- Reactに依存しない純粋TypeScriptが対象です
- 業務ルールを持たない汎用処理が対象です（文字列操作・日付フォーマット・数値丸め・配列操作等）

## ドメインロジックとの違い

`domain/`は業務ルール・制約・変換を扱うのに対し、`utils/`はそのプロジェクト以外でも使える汎用処理を扱います。テストの観点も自然と変わります。

| 観点 | `domain/` | `utils/` |
|---|---|---|
| 主軸 | 業務ルールの正しさ | 入出力の網羅 |
| エラー型 | `Result<T, E>`で業務エラーを表現 | 引数バリデーション失敗時の挙動（throw / undefined返却等） |
| ソート・順序 | 業務的な順序（券種ソート等） | 一般的な順序（昇順・降順） |

汎用処理は`domain-test-patterns.md`のような細かい型パターン分類が不要なので、観点ごとのテンプレートを置きます。

## 共通ルール

- ファイル先頭に`VERIFY:meta`を必ず追加します（仕様は`verify-comment-spec.md`）
- 2行目にテスト実行コマンドをコメントで記載します
- importは`from 'vitest'`と対象ファイルからの相対importのみにします
- `describe`でグループ化し、`it`で個別ケースを記述します
- 同じ構造のケースが3つ以上続く場合は`it.each`でテーブルにまとめます

## ファイル配置と命名

```
src/utils/
├── format-date.ts
└── format-date.test.ts
```

## 観点別のテンプレート

### 観点1: 入出力テーブル

もっとも基本的なパターンです。引数と期待値を`it.each`で網羅します。

```ts
// VERIFY:meta
//   対象機能:           日付の表示用フォーマット
//   想定ユーザー:       このモジュールを呼び出すコード
//   目的:               Dateオブジェクトを 'YYYY-MM-DD' 形式に変換する
//   前提条件:           入力は有効なDate
//   起こり得る外部条件: cond.time (タイムゾーン)
//   テスト範囲外:       無効なDateの挙動（呼び出し側で弾く前提）
//   最終レビュー日:     2026-05-13

// npm run test:run -- src/utils/format-date.test.ts
import { describe, it, expect } from 'vitest';
import { formatDate } from './format-date';

describe('formatDate', () => {
  it.each([
    { input: new Date('2026-01-15T00:00:00Z'), expected: '2026-01-15' },
    { input: new Date('2026-12-31T23:59:59Z'), expected: '2026-12-31' },
    { input: new Date('2026-02-29T12:00:00Z'), expected: '2026-02-29' },  // うるう年
  ])('$input → $expected', ({ input, expected }) => {
    expect(formatDate(input)).toBe(expected);
  });
});
```

### 観点2: 境界値

数値・配列・文字列の境界を網羅します。

```ts
// npm run test:run -- src/utils/clamp.test.ts
import { describe, it, expect } from 'vitest';
import { clamp } from './clamp';

describe('clamp', () => {
  it.each([
    { value:  5, min: 0, max: 10, expected:  5, desc: '範囲内の値はそのまま返す' },
    { value:  0, min: 0, max: 10, expected:  0, desc: '最小値は通す' },
    { value: 10, min: 0, max: 10, expected: 10, desc: '最大値は通す' },
    { value: -1, min: 0, max: 10, expected:  0, desc: '最小値を下回る場合はminに丸める' },
    { value: 11, min: 0, max: 10, expected: 10, desc: '最大値を超えた場合はmaxに丸める' },
  ])('$desc: clamp($value, $min, $max) → $expected', ({ value, min, max, expected }) => {
    expect(clamp(value, min, max)).toBe(expected);
  });
});
```

### 観点3: エラー処理

汎用関数でも引数バリデーション失敗時の挙動は明示します。

```ts
// npm run test:run -- src/utils/parse-csv.test.ts
import { describe, it, expect } from 'vitest';
import { parseCsv } from './parse-csv';

describe('parseCsv', () => {
  describe('正常系', () => {
    it('カンマ区切りをパースできる', () => {
      expect(parseCsv('a,b,c')).toEqual(['a', 'b', 'c']);
    });

    it('空文字列は空配列を返す', () => {
      expect(parseCsv('')).toEqual([]);
    });
  });

  describe('異常系', () => {
    it.each([null, undefined])('値が指定されていない場合はエラーになる（%s）', (input) => {
      expect(() => parseCsv(input as unknown as string)).toThrow(TypeError);
    });
  });
});
```

### 観点4: 純粋性の確認（必要時のみ）

引数を変更しないこと（イミュータビリティ）を確認したいときに使います。

```ts
// npm run test:run -- src/utils/uniq.test.ts
import { describe, it, expect } from 'vitest';
import { uniq } from './uniq';

describe('uniq', () => {
  it('重複を除去する', () => {
    expect(uniq([1, 2, 2, 3])).toEqual([1, 2, 3]);
  });

  it('元の配列を変更しない', () => {
    const original = [1, 2, 2, 3];
    const snapshot = [...original];

    uniq(original);

    expect(original).toEqual(snapshot);
  });
});
```

### 観点5: ロケール・タイムゾーン依存

日付・数値フォーマットなど、環境に依存する関数では明示的にロケール・TZを固定します。

```ts
// npm run test:run -- src/utils/format-currency.test.ts
import { describe, it, expect } from 'vitest';
import { formatCurrency } from './format-currency';

describe('formatCurrency', () => {
  it.each([
    { amount: 1234, locale: 'ja-JP', expected: '¥1,234' },
    { amount: 1234, locale: 'en-US', expected: '$1,234.00' },
    { amount: 1234, locale: 'de-DE', expected: '1.234,00 €' },
  ])('$locale: $amount → $expected', ({ amount, locale, expected }) => {
    expect(formatCurrency(amount, locale)).toBe(expected);
  });
});
```

タイムゾーン依存の関数はVitestの`vi.setSystemTime()`や`process.env.TZ`で固定します。

```ts
import { describe, it, expect, beforeAll, afterAll } from 'vitest';

describe('formatDate (TZ依存)', () => {
  const originalTZ = process.env.TZ;
  beforeAll(() => { process.env.TZ = 'Asia/Tokyo'; });
  afterAll(() => { process.env.TZ = originalTZ; });

  it('JSTで日付を返す', () => {
    expect(formatDate(new Date('2026-01-15T15:00:00Z'))).toBe('2026-01-16');
  });
});
```

## テスト実行

```bash
npm run test:run -- src/utils/xxx.test.ts
```

## 設計改善のチェックリスト

### チェック1: そもそも`utils/`に置くべきか

業務ルールが混じっていたら`domain/`の対象です。`test-target-classification.md`の段階3を再確認します。

### チェック2: 引数の型が広すぎないか

`any` / `unknown` / `object`が混じっていないか確認します。型を絞れば多くの異常系テストが不要になります。

### チェック3: 副作用が混じっていないか

`Date.now()` / `Math.random()` / グローバル変数参照が関数内にあれば、引数で受け取る形に変えるとテストが書きやすくなります（domainと同じ指針）。

### チェック4: テスト名が振る舞いを記述しているか

`formatDate のテスト`ではなく`2026-01-15 を YYYY-MM-DD で返す`のように、入力と期待結果を記述します。

### チェック5: 既存のライブラリで代替できないか

`date-fns`や`lodash-es`で同等の機能があるなら、自前実装を捨ててライブラリに寄せることを提案します。テストの保守コストが下がります。
