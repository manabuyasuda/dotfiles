# プロジェクト構造の把握とコンポーネント選定

React / Next.jsプロジェクトのコンポーネント配置・命名規約を把握し、既存共通コンポーネントの流用と新規共通化を判断する手順です。

`references/project-instructions.md`の「アーキテクチャ・設計の参照ドキュメント」「採用しているアーキテクチャパターン」「コンポーネント配置・命名規約」「既存共通コンポーネント」見出しに記載があれば、それを最優先します。記載がなければ以下の手順で自律判断します。

## Step 1: 採用しているアーキテクチャパターンを把握する

プロジェクトが採用しているアーキテクチャパターンによって、コンポーネントの配置場所・命名規約・責務の分担が変わります。最初にパターンを把握してから配置を判断します。

代表的なパターンは以下です。

| パターン | 概要 |
|---|---|
| Atomic Design | UIをAtoms / Molecules / Organisms / Templates / Pagesの5層に分割 |
| Feature-Sliced Design (FSD) | 機能・層・セグメントの3軸でコードを整理 |
| Container/Presentational | ロジックとUIを分離 |
| Package by Layer / Feature | レイヤー単位または機能単位でディレクトリ分割 |
| Colocation | 関連コード（テスト・スタイル・データフェッチ）を使う場所の近くに置く横断原則 |

これらは排他ではなく組み合わせて使われます（例: FSD + Atomic Designは`shared/ui`にAtoms / Moleculesを置く形式）。

各パターンの詳細解説ドキュメントがプロジェクト内またはユーザー環境にある場合は、`references/project-instructions.md`の「アーキテクチャ・設計の参照ドキュメント」見出しにパスを記載してください。記載があればそれを最優先で参照します。

採用パターンの判断は以下のコマンドで行います。

```bash
# Atomic Designの手がかり
find src -type d \( -name "atoms" -o -name "molecules" -o -name "organisms" -o -name "templates" \) 2>/dev/null | head

# FSDの手がかり
find src -type d \( -name "shared" -o -name "entities" -o -name "features" -o -name "widgets" \) -maxdepth 2 2>/dev/null | head

# Container/Presentationalの手がかり（hooks集約ディレクトリ）
find src -type d \( -name "hooks" -o -name "containers" \) -maxdepth 3 2>/dev/null | head
```

判断がつかなければ、Step 6でユーザーに確認します。

## Step 2: ディレクトリ構成を把握する

実装対象のコンポーネントをどこに配置すべきかを判断するため、Step 1で特定したパターンに沿った配置場所を確認します。

```bash
# トップレベルのディレクトリ構造（深さ3まで）
find src -type d -maxdepth 3 2>/dev/null || find app components -type d -maxdepth 3 2>/dev/null
```

代表的な配置パターンは以下です。

| パターン | 配置例 |
|---|---|
| Atomic Design | `src/components/{atoms,molecules,organisms,templates}/` |
| FSD | `src/{shared,entities,features,widgets,pages}/{slice}/ui/` |
| feature-based | `src/features/{feature}/components/` |
| layer-based | `src/components/{ui,layout,feature}/` |
| Next.js App Router | `app/{route}/_components/`（共通は`components/`） |
| Next.js Pages Router | `pages/` + `components/` |

## Step 3: ファイル命名規約を把握する

```bash
# 既存コンポーネントファイルの命名パターンをサンプリング
find src app components -type f \( -name "*.tsx" -o -name "*.jsx" \) 2>/dev/null | head -20
```

確認するポイントは以下です。

| 観点 | 例 |
|---|---|
| ファイル名 | `PascalCase.tsx` / `kebab-case.tsx` |
| ディレクトリ集約 | `Button/index.tsx` + `Button/Button.module.css` / 単一ファイル`Button.tsx` |
| Stylesファイル | `Button.module.css` / `Button.css.ts` / `Button.styles.ts` |
| Storyファイル | `Button.stories.tsx` |
| テストファイル | `Button.test.tsx` |

新規コンポーネントは同じパターンに揃えます。

## Step 4: 既存共通コンポーネントを探す

実装対象と同じUIパターンがすでに存在する場合は流用します。探索順序は以下です。

### Step 4-1: マッピングファイルのCode Connect情報を確認

figma-extractの出力にコンポーネントインスタンスの情報が含まれていれば、対応するコードベースのコンポーネントが特定されています。これを最優先に確認します。

### Step 4-2: 同じ画面の隣接コンポーネントを読む

実装対象が含まれる画面の他のコンポーネント実装を確認し、同じUIパターン（ボタン・カード・リスト等）がどのコンポーネントで実装されているかを確認します。

### Step 4-3: 関連ページを確認する

「実装対象ページの関連ページ」も確認します。隣接ページや同じ機能区分のページで共通化済みのコンポーネントを発見できる場合もあります。

| 関連ページとして確認する対象 |
|---|
| 同じ機能区分の他ページ（例: 商品詳細を実装するなら商品一覧・カート） |
| 同じ階層・同じディレクトリ内の他ページ |
| 同じレイアウトを使う他ページ（App Routerなら同じ`layout.tsx`配下） |

```bash
# Next.js App Routerの場合、同じレイアウト配下のページを確認
find app -type f -name "page.tsx" 2>/dev/null | head -20

# 同じ機能ディレクトリ内の他コンポーネントを確認
find src/features/{feature} -type f -name "*.tsx" 2>/dev/null
```

### Step 4-4: 共通コンポーネントディレクトリをgrep

```bash
# コンポーネント名・用途で検索（例: ボタン）
grep -rn "Button\|button" src/components src/ui app/components src/shared 2>/dev/null --include="*.tsx" -l | head
```

### 流用判断の基準

以下の条件をすべて満たす場合のみ流用します。

- 用途がファイルパス・コメント・Props名から明確に判断できる
- 特定の文脈（特定ページ・特定機能）に依存していない
- マッピングファイルのスタイルと既存コンポーネントの見た目が一致する

特定文脈向けに特化されているコンポーネント（例: `RaceListItemButton`）は、たとえ見た目が近くても流用しません。

## Step 5: 新規共通化の判断

実装対象が既存共通コンポーネントに該当しない場合、ローカル実装か新規共通コンポーネントかを決めます。

### 共通化する場合の条件

以下のすべてを満たす場合のみ共通化します。

- 同じUIパターンが2箇所以上で使われる（または使われることが確定している）
- 文脈依存のロジック・データ表示を含まない
- 共通化先のディレクトリ（Atomic Designなら`atoms/molecules/`、FSDなら`shared/ui/`）がすでに存在する、または新設の合意がある

### 共通化しない場合（ローカル実装）

- 1箇所でしか使われない
- 特定ページ・特定機能のロジックを含む
- 共通化するか不明な段階

迷ったらローカル実装にします。後から共通化する方が、文脈に合わない共通化を解体するより手戻りが少ないためです。

## Step 6: 配置場所と命名を決定する

Step 1〜5で得た情報から、新規コンポーネントの配置場所とファイル名を決めます。

| 種別 | 配置場所の例 | 命名 |
|---|---|---|
| Atomic Design - Atoms | `src/components/atoms/{ComponentName}/` | `PascalCase` |
| Atomic Design - Molecules | `src/components/molecules/{ComponentName}/` | `PascalCase` |
| FSD - shared/ui | `src/shared/ui/{component-name}/` | プロジェクトに合わせる |
| 機能専用 | `src/features/{feature}/components/{ComponentName}/` | `PascalCase` |
| ルート専用（App Router） | `app/{route}/_components/{ComponentName}/` | `PascalCase` |

## Step 7: ユーザーへの提案と承諾を得る

実装着手前に、Step 1〜6の判断結果をユーザーへ提案して承諾を得てください。判断を誤った状態で実装が進むと、認識合わせがやり直しになり、手戻りが大きくなります。

### 承諾を省略できる条件（escape hatch）

`references/project-instructions.md`の以下の見出しがすべて埋まっていて、Step 1〜6の判断がそれに沿っている場合は、承諾フェーズを省略して合意内容の提示のみで次のStepに進めます。

- 「アーキテクチャ・設計の参照ドキュメント」または「採用しているアーキテクチャパターン」
- 「コンポーネント配置・命名規約」
- 「既存共通コンポーネント」

これらが埋まっていれば、判断の余地が少なく、ユーザーは事前にルールを表明済みだからです。1項目でも空欄ならescape hatchは使えず、通常の承諾フェーズに進みます。

### 進め方

質問・確認のルールは`references/project-confirmation.md`にしたがってください。

このStepでの抽象→具体の絞り込み順は以下です。

- 抽象: 採用しているアーキテクチャパターン（Atomic Design / FSD等）
- 具体: 配置場所・命名・既存流用の有無

### 提案で必ず触れる項目

| 項目 | 内容 |
|---|---|
| 採用しているアーキテクチャパターン | Step 1で特定したパターン（Atomic Design / FSD等）と、自律推測の場合はその根拠 |
| 配置場所 | 新規作成するコンポーネントのファイルパス |
| 命名 | コンポーネント名・ファイル名 |
| 既存流用の有無 | 流用するコンポーネントのファイルパスと判断理由（あれば） |
| 新規共通化の有無 | 共通化する場合は対象UIパターンと利用箇所（2箇所以上） |
| 不確実な点 | 自律推測で確証がない箇所・関連ページの確認結果で迷いが残った箇所 |

質問文の例は以下です。

| 確認したい分岐 | 質問文（はい/いいえで答えられる肯定文） |
|---|---|
| アーキテクチャパターンの特定 | 「このプロジェクトはAtomic Designを採用していますか？」（はい=Atomic / いいえ=他パターンへ深掘り） |
| 既存流用の妥当性 | 「`src/components/ui/Button/Button.tsx`を流用してよいですか？」（はい=流用 / いいえ=新規実装へ） |
| 共通化の判断 | 「このコンポーネントは2箇所以上で使われる見込みですか？」（はい=共通化 / いいえ=ローカル実装） |

承諾を得てからStep 4（アイコン・画像の準備）以降に進みます。承諾なしで実装に入ってはいけません。

### ユーザーに確認・相談すべきタイミング

以下のいずれかに該当する場合は、Step 7の最終提案を待たずに途中でも相談します。

- Step 1でアーキテクチャパターンの特定が自力でできない
- Step 4-3の関連ページ確認で「共通化されているか怪しい」コンポーネントが見つかった
- Step 5の共通化判断で「2箇所目で使われる可能性」の判断材料が不足している
- 命名規約に複数のパターンが混在しており、どちらに揃えるべきか判断できない

早めの相談で誤った方向を防ぎます。
