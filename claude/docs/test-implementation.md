# テスト実装ルール

## テスト名は振る舞いを宣言する形で書く

実装の関数名やメソッド名ではなく、「どういう条件のときにどういう結果になるか」を書きます。実装名を含めると、リファクタリングで実装名が変わるたびにテスト名も追従が必要になり、失敗ログから何が壊れたかも判断しにくくなります。否定的な振る舞いは「〜しない」より「〜を拒否する」のように肯定的な動詞で書きます。

```typescript
// 悪い例
it("withdrawメソッドのテスト", () => {});
it("isValidがfalseを返す", () => {});
it("エラーを返さない", () => {});

// 良い例
it("残高が不足している場合は引き出しを拒否する", () => {});
it("メールアドレスに@が含まれない場合は無効と判定する", () => {});
it("有効な入力に対して正常な値を返す", () => {});
```

「実装名を含めない」の対象は関数名・メソッド名に限りません。型名・クラス名・内部フラグ名・言語固有の構造名も同じく含めません。テスト名はそのシステムの仕様を知っている非エンジニアが読んでも意味がわかる言葉で書きます。コードを読まないと意味がわからないテスト名は、実装の内部事情が混入しているサインです。

```typescript
// 悪い例（コードを読まないと意味がわからない）
it("ブランド型として返す", () => {});
it("Resultオブジェクトを返す", () => {});

// 良い例（仕様書に書いてあるような言葉で表現）
it("有効な注文者IDとして受け付ける", () => {});
it("注文が存在しない場合は取得に失敗する", () => {});
```

### describeのグループ名はドメインの言葉で書く

`describe`のグループ名は実装上の区分（数値コード・フラグ値等）ではなく、ドメインの言葉で表現します。グループ名を見るだけでそのブロックが何を検証しているかわかります。

```typescript
// 悪い例
describe("status=0", () => { ... });
describe("status=1", () => { ... });
describe("status=2", () => { ... });

// 良い例
describe("処理中", () => { ... });
describe("完了", () => { ... });
describe("キャンセル済み", () => { ... });
```

## AAA（Arrange/Act/Assert）を空行で分離する

前提条件（Arrange）、実行（Act）、検証（Assert）の3ブロックを必ず空行で分けます。コメントは不要ですが、空行は必須です。

```typescript
// 悪い例
it("送金額が残高を超える場合はエラーになる", () => {
  const account = new BankAccount(100);
  expect(() => account.withdraw(200)).toThrow("残高不足");
});

// 良い例
it("送金額が残高を超える場合はエラーになる", () => {
  const account = new BankAccount(100);

  const act = () => account.withdraw(200);

  expect(act).toThrow("残高不足");
});
```

## 1つのテストには1つのActしか置かない

1つの`it`内で起動する振る舞いは1つだけにします。複数のActを詰め込むと、どのアクションが失敗を引き起こしたかが失敗ログだけからは特定できなくなります。

```typescript
// 悪い例
it("入金と出金", () => {
  const account = new BankAccount(0);

  account.deposit(100);
  account.withdraw(50);

  expect(account.balance).toBe(50);
});

// 良い例
it("入金すると残高が増える", () => {
  const account = new BankAccount(0);

  account.deposit(100);

  expect(account.balance).toBe(100);
});

it("出金すると残高が減る", () => {
  const account = new BankAccount(100);

  account.withdraw(50);

  expect(account.balance).toBe(50);
});
```

## 期待値はハードコードする

アサーションの期待値はリテラルで書きます。プロダクトコードと同じ計算式で期待値を導出すると、プロダクト側のバグが期待値計算にもコピーされ、両方間違っているのにテストが通る状況（自作自演テスト、偽陰性）が発生します。`it.each`でも`expected`をループ内で計算せず、テーブルにすべてリテラルで書きます。

```typescript
// 悪い例
it("10%割引を計算する", () => {
  const price = 1000;
  const rate = 0.1;

  expect(calculateDiscount(price, rate)).toBe(price * rate);
});

// 良い例
it("1000円に10%割引を適用すると100円になる", () => {
  expect(calculateDiscount(1000, 0.1)).toBe(100);
});

it.each([
  { price: 1000, rate: 0.1, expected: 100 },
  { price: 2000, rate: 0.2, expected: 400 },
  { price: 0,    rate: 0.5, expected: 0   },
])("価格$priceに割引率$rateを適用すると$expectedになる", ({ price, rate, expected }) => {
  expect(calculateDiscount(price, rate)).toBe(expected);
});
```

## 観測可能な出力だけをアサートする

戻り値、例外、公開APIで観測できる状態変化、管理外の依存への送信内容のみを検証します。プライベートメソッド、内部フィールド、内部のメソッド呼び出し回数といった実装の詳細は検証しません。判断基準として、「そのアサーションが落ちたらユーザーや下流の連携先に観測可能な不具合が起きているか」を自問し、Noなら別の観測点を探します。

```typescript
// 悪い例
it("登録処理の途中でフラグが立つ", () => {
  const service = new UserService();

  service.register("a@b.com");

  expect((service as any)._isProcessing).toBe(true);
});

// 良い例
it("登録するとユーザー一覧から取得できるようになる", () => {
  const service = new UserService();

  service.register("a@b.com");

  expect(service.findAll()).toContainEqual(
    expect.objectContaining({ email: "a@b.com" }),
  );
});
```

「メソッドが呼ばれたか」を検証する相互作用ベースのアサーションは、状態ベースのアサーションよりも実装の詳細に近づきます。可能な限り「結果がどうなったか」を見ます。

## テストデータはそのケースで意味のある値だけを目立たせる

ファクトリやビルダーで型として有効な最小データを返し、テストごとに意味のあるフィールドだけoverrideします。フィラー値は`"x"`、`0`、`null`のように意味の薄さが伝わる値を選びます。`"Alice"`のような実在しそうな値は「Aliceであることに意味がある」と読まれてしまうため、デフォルト値には使いません。

```typescript
// 悪い例
it("18歳未満は登録できない", () => {
  const user = {
    id: "u1",
    name: "Alice",
    email: "alice@example.com",
    age: 17,
    createdAt: new Date("2024-01-01"),
    role: "user",
  };

  expect(canRegister(user)).toBe(false);
});

// 良い例
it("18歳未満は登録できない", () => {
  const user = buildUser({ age: 17 });

  expect(canRegister(user)).toBe(false);
});
```

テスト名に書いた条件と、テストデータの値が一致しているか必ず確認します。境界値を扱うテストでは、境界の内側と外側を異なるテストに分け、それぞれのテスト名にその数値を含めます。

## テストダブルは役割で選ぶ

ダブルを使う前に「間接入力を制御したいのか、間接出力を検証したいのか」を決めます。値を返すクエリにはスタブ（戻り値や状態を検証）、副作用を起こすコマンドにはモック（呼び出しを検証）を使います。同じオブジェクトをスタブとモックの両方として使ってはいけません。検証するモックは1つのテストにつき原則1つです。

```typescript
// 悪い例
const repo = {
  findById: vi.fn().mockReturnValue(user),
  save: vi.fn(),
};

service.process(repo);

expect(repo.save).toHaveBeenCalled();

// 良い例
const repoStub = { findById: vi.fn().mockReturnValue(user) };
const repoMock = { save: vi.fn() };

service.process({ ...repoStub, ...repoMock });

expect(repoMock.save).toHaveBeenCalledWith(
  expect.objectContaining({ id: user.id })
);
```

## プロセス内依存と管理下の依存はモックしない

モックすべきはプロセス外かつ管理外の依存（外部API、SMTPサーバー、サードパーティSaaSなど）のみです。同一プロセス内のクラスや関数（プロセス内依存）は本物を使います。自社が制御するDBやキュー（管理下の依存）はモックではなく本物かFake実装（インメモリ実装）を使います。理由は、プロセス内依存と管理下の依存への呼び出しは実装の詳細であり、モックすると内部構造の変更でテストが大量に壊れるためです。

```typescript
// 悪い例
const calc = vi.spyOn(Calculator.prototype, "add").mockReturnValue(5);

const dbMock = { saveUser: vi.fn() };
service.register(dbMock, "a@b.com");
expect(dbMock.saveUser).toHaveBeenCalled();

vi.spyOn(global, "fetch").mockResolvedValue(new Response("..."));

// 良い例
const calculator = new Calculator();
const result = calculator.add(2, 3);
expect(result).toBe(5);

const db = new InMemoryUserRepository();
await service.register(db, "a@b.com");
expect(await db.findByEmail("a@b.com")).toBeTruthy();

server.use(
  http.post("https://mailer.example.com/send", async ({ request }) => {
    const body = await request.json();
    expect(body).toMatchObject({ to: "a@b.com" });
    return HttpResponse.json({ ok: true });
  }),
);
```

HTTP境界はネットワーク層でモックします。`fetch`や`axios`の関数自体をスパイで置き換えるのではなく、MSWでリクエスト・レスポンスを差し替えます。

## 非決定性は制御可能にしてから書く

時刻、乱数、HTTP通信、タイマーなど非決定的な要素は、外部から固定可能にした上でテストを書きます。`Clock`インターフェースを注入する設計、`vi.useFakeTimers()`と`vi.setSystemTime()`、シードを受け取る関数、MSWといった手段を使います。テスト側で`Date.now()`を直接モックするのは最終手段です。

```typescript
// 悪い例
class Subscription {
  isExpired(): boolean {
    return Date.now() > this.expiresAt;
  }
}

// 良い例
interface Clock {
  now(): number;
}

class Subscription {
  constructor(private clock: Clock) {}
  isExpired(): boolean {
    return this.clock.now() > this.expiresAt;
  }
}

it("現在時刻が期限を過ぎている場合は期限切れと判定する", () => {
  const fakeClock: Clock = { now: () => new Date("2024-06-01").getTime() };
  const sub = new Subscription(fakeClock);
  sub.expiresAt = new Date("2024-01-01").getTime();

  expect(sub.isExpired()).toBe(true);
});
```

非同期処理では任意のミリ秒スリープ（`await new Promise(r => setTimeout(r, 1000))`）は禁止です。明示的な期待状態を待ちます。

## テスト間で共有可変状態を作らない

各テストの開始時に状態を必ず初期化します。`beforeAll`で1回だけ作って使い回す、モジュールスコープの変数を変更する、グローバル設定を書き換えて戻し忘れる、といったパターンは順序依存と並列実行の問題を生みます。`beforeEach`でfreshな状態から始め、書き換えたグローバルは`afterEach`で復元します。

```typescript
// 悪い例
const repo = new UserRepository();

beforeAll(async () => {
  await repo.seed();
});

it("ユーザーを取得できる", async () => {
  const user = await repo.findById(1);
  expect(user).toBeTruthy();
});

it("ユーザーを削除できる", async () => {
  await repo.delete(1);
  expect(await repo.findById(1)).toBeNull();
});

// 良い例
let repo: UserRepository;

beforeEach(async () => {
  repo = new UserRepository();
  await repo.seed();
});

it("ユーザーを取得できる", async () => {
  const user = await repo.findById(1);
  expect(user).toBeTruthy();
});

it("ユーザーを削除できる", async () => {
  await repo.delete(1);
  expect(await repo.findById(1)).toBeNull();
});
```

`vi.mock`のリセットは`vi.clearAllMocks()`または`vi.restoreAllMocks()`をsetupファイルで自動化します。並列実行で安全か（共有DBはスキーマ分離やトランザクションロールバックで対応）も書く時点で意識します。

## 失敗時の診断性を最優先する

テストが落ちたとき、失敗ログだけを読んで原因が特定できる状態に保ちます。アサーションは粒度を上げ、巨大なオブジェクト全体の比較ではなく本質のフィールドだけを比較します。スナップショットは大きすぎると差分から原因を読み解けないため、意味のある単位に絞ります。`toEqual`（完全一致）と`toMatchObject`（部分一致）は使い分けます。

```typescript
// 悪い例
const result = await orderService.placeOrder(input);

expect(result).toEqual({
  id: expect.any(String),
  customerId: "c1",
  items: [...],
  status: "completed",
  totalAmount: 1500,
  createdAt: expect.any(Date),
  updatedAt: expect.any(Date),
  metadata: { ... },
});

// 良い例
const result = await orderService.placeOrder(input);

expect(result).toMatchObject({
  status: "completed",
  totalAmount: 1500,
});
```

`toBeValidUser`のようなカスタムマッチャーは失敗ログが無情報になるため、標準マッチャーで具体的に書きます。

## テストが書きにくいと感じたら設計の匂いを疑う

テストを通すためにテストを曲げてはいけません。`as any`で型を回避する、privateを暴露する、複雑なモック階層を組む、といった対応はせず、プロダクトコードの設計を疑います。以下の症状が出たら設計改善の起点にします。

| 症状 | 疑うべき設計 |
|---|---|
| モックが5個以上必要 | 依存が多すぎます。ドメインロジックとI/Oが混ざっています |
| Arrangeが極端に長い | 制御容易性が低く、前提条件のセットアップに別オブジェクトの組み立てが必要です |
| 戻り値がなく副作用しか検証できない | 純粋関数として切り出せる部分がないか検討します |
| `any`キャストやprivate暴露が必要 | 観測容易性が低く、公開APIに観測点がありません |
| 時刻や乱数を直接書き換える必要がある | 非決定的な依存が注入されていません |
| テスト対象を初期化するのにDB、ネットワーク、DOMが必要 | Functional Coreが分離されていません |

テスト容易性は、観測容易性、制御容易性、対象の小ささの3要素で評価できます。書きにくいテストに直面したら、この3軸のどれが不足しているかを特定し、その軸を改善する方向にプロダクトコードをリファクタリングします。

## フロントエンド固有のルール

### Testing Libraryのクエリ優先順位を守る

`getByRole`を最優先にし、続いて`getByLabelText`、`getByPlaceholderText`、`getByText`、最後に`getByTestId`の順で選びます。ロールやラベル経由のクエリはユーザーがUIを認識する経路と一致するため、クエリの選択がアクセシビリティ品質の担保にもなります。`testid`は実装の詳細であり、マークアップ変更で簡単に壊れます。

### `userEvent`を使い、`fireEvent`は使わない

`fireEvent`は単一のDOMイベントを直接ディスパッチするだけで、本物のブラウザのイベント順序（`pointerdown`、`mousedown`、`focus`、`pointerup`、`mouseup`、`click`の連鎖）を再現しません。`userEvent.setup()`を使います。

```typescript
// 悪い例
fireEvent.click(button);
fireEvent.change(input, { target: { value: "hello" } });

// 良い例
const user = userEvent.setup();
await user.click(button);
await user.type(input, "hello");
```

### 非同期UIは`findBy`または`waitFor`の明示的条件で待つ

非同期で表示・更新される要素は`findByRole`などのタイムアウト付きクエリを使います。`waitFor`を使う場合は待つ条件を関数で明示します。

```typescript
// 悪い例
await new Promise(r => setTimeout(r, 1000));
expect(screen.getByText("成功")).toBeInTheDocument();

// 良い例
expect(await screen.findByText("成功")).toBeInTheDocument();
```

### `act()`警告は無視しない

`act()`警告は「Reactの状態更新がテストで観測されないまま終わっている」サインです。`userEvent`、`findBy`、`waitFor`で正しく非同期更新を待つ形にリファクタリングします。`console.error`をスパイで握り潰す対応は禁止です。

### MSWでネットワーク境界をモックする

`fetch`や`axios`を直接モックせず、MSWでリクエスト境界を差し替えます。プロダクトコードのネットワーククライアント実装はそのまま動かせ、テストごとに`server.use()`でハンドラを上書きできます。

```typescript
// 悪い例
vi.spyOn(global, "fetch").mockResolvedValue(
  new Response(JSON.stringify([{ id: 1, name: "Alice" }]))
);

// 良い例
server.use(
  http.get("/api/users", () =>
    HttpResponse.json([{ id: 1, name: "Alice" }])
  ),
);
```

### カスタムフックは`renderHook`でテストする

フック単体の振る舞いは`renderHook`で直接テストします。コンポーネント経由でフックをテストすると、コンポーネント側の事情（再レンダリング、propsの変更）がノイズになります。コンテキストが必要なフックは`wrapper`オプションで最小限のプロバイダーを渡します。

```typescript
const wrapper = ({ children }: { children: ReactNode }) => (
  <QueryClientProvider client={new QueryClient()}>
    {children}
  </QueryClientProvider>
);

const { result } = renderHook(() => useUsers(), { wrapper });
```
