---
name: figma-implement
description: >
  figma-extractが生成したマッピングファイルとスクリーンショットをもとに、Figmaのデザインに合わせてコンポーネントやページを実装するスキル。
  「このFigmaのデザインを実装して」「Figmaに合わせてコンポーネント作って」「デザインを再現して」「Figmaどおりに実装して」
  「マッピングファイルから実装して」「extractしたデータで実装を進めて」「Figmaのnode-idを実装して」のように依頼されたとき、
  またはfigma-extractの直後に実装フェーズへ進むときに必ず起動してください。
  Figma URLが渡されて実装まで一気に依頼された場合は、まずfigma-extractで取得・マッピングを終えてから本スキルを起動します。
  デザイン取得・トークン引き当て・マッピングファイル作成自体は本スキルの対象外です。それらはfigma-extractで実行してください。
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - AskUserQuestion
  - mcp__playwright__screenshot
  - mcp__playwright__browser_evaluate
  - mcp__playwright__browser_hover
  - mcp__playwright__browser_snapshot
---

# figma-implement

このスキルはfigma-extractの成果物を入力として、コンポーネント単位のデザイン再現を行います。アーキテクチャ設計・状態管理・ルーティング・データフェッチングは対象外です。

## figma-extractとの連動

Figma URLや「このデザインを実装して」のように依頼された場合、本スキルは単体では動きません。以下の順で連動します。

1. **figma-extract**が起動: Figma MCPからデータを取得し、マッピングファイルとスクリーンショットを保存する
2. figma-extractの完了後、**figma-implement**（本スキル）が起動: Step 1の入力チェックから実装と検証まで進める

ユーザーから「Figma URL → 実装まで」とまとめて依頼されたときは、まずfigma-extractスキルを呼び出して成果物を揃え、続けて本スキルへ進みます。マッピングファイルがすでに存在する場合は本スキルから開始します。

| 対象 | 範囲 |
|---|---|
| UIフレームワーク | React / Next.jsのみ |
| CSSフレームワーク | Tailwind / Panda / vanilla-extract / CSS Modulesの4種 |

| ファイル | 内容 | 参照タイミング |
|---|---|---|
| `references/project-instructions.md` | プロジェクト固有のユーザー指示（最優先） | 全Step |
| `references/project-confirmation.md` | ユーザーへの提案・承諾の質問ルール | Step 3・Step 4 |
| `references/project-components.md` | アーキテクチャパターン・配置・命名・既存共通コンポーネント探索 | Step 2・Step 3 |
| `references/project-icons.md` | 単色/多色アイコンの実装分岐 | Step 4 |
| `references/project-images.md` | フォーマット判定・解像度バリエーション・Image方式分岐・art direction | Step 4 |
| `references/project-tokens.md` | 4FW別のトークン適用方法 | Step 5 |
| `references/project-verification.md` | スクショ・getComputedStyle・getBoundingClientRect・画像差分・a11yツリー | Step 6 |

各Stepで、まず`references/project-instructions.md`の該当見出しを確認します。記載があればそれを最優先します。記載がなければ各referenceの手順で自律判断します。

## Step 1: 入力チェック

figma-extractの成果物が揃っているか確認します。マッピングファイル・スクリーンショットの正式な保存先パスはfigma-extractスキルの`references/project-save-format.md`から参照してください。figma-extract側で保存形式が変更されている可能性があるため、毎回ここから読み取ります。

| 確認項目 | 方法 |
|---|---|
| マッピングファイルが存在する | figma-extract側の保存形式に従ったパスを`ls`で確認 |
| スタイル表のトークン列にすべて値が入っている | ファイルを開いて目視確認 |
| テキスト・アイコン・画像の各表が記録されている | マッピングファイルのテンプレートと照合 |
| スクリーンショットが保存されている | figma-extract側の保存形式に従ったパスを`ls`で確認 |

1つでも欠けていればfigma-extractに戻ります。空欄のままトークンを推測して実装しないでください。

### Step 1で読み取った情報は以降のStepで再利用する

マッピングファイルにはStep 2以降で使う情報が含まれています。読み取った内容は記憶しておき、再読込みを避けてください。

| 読み取った情報 | 使うStep |
|---|---|
| Code Connect（コンポーネントインスタンスのコード対応） | Step 3（既存共通コンポーネント探索の最優先候補） |
| アイコン表（種別・サイズ・色トークン） | Step 4（アイコン実装方法の分岐判断） |
| 画像表（用途・サイズ・object-fit） | Step 4（画像方式・art directionの判断） |
| スタイル表のトークン | Step 5（スタイル実装の入力） |
| レイアウト算出値（親X中 x=Y w=Z） | Step 6（`getBoundingClientRect`での照合） |

## Step 2: プロジェクト構造を把握する

1. `references/project-instructions.md`の「アーキテクチャ・設計の参照ドキュメント」「採用しているアーキテクチャパターン」見出しに記載があるか確認します
2. 記載がなければユーザーに「参照すべきアーキテクチャドキュメントや設計資料はあるか」を尋ねます
3. ユーザー回答もなければ`references/project-components.md`のStep 1〜3で自律推測します

把握した結果（採用しているアーキテクチャパターン・コンポーネントの配置場所・命名規約）はStep 3の判断材料になります。

## Step 3: コンポーネントを選定する

`references/project-components.md`のStep 4〜6で、以下を決定します。

- 既存共通コンポーネントを流用する
- 新規にローカルコンポーネントとして実装する
- 新規に共通コンポーネントとして実装する

判断には実装対象ページの関連ページ（同じ機能区分・同じレイアウト配下）の確認も含みます。共通化されている箇所が関連ページに見つかることがあります。

実装着手前に、判断結果をユーザーへ提案して承諾を得てください。詳細とescape hatch（承諾省略の条件）は`references/project-components.md`のStep 7を参照します。

判断材料が不足する場合は、最終提案を待たずに途中でも相談してください。誤った方向に進むと認識合わせがやり直しになります。

## Step 4: アイコン・画像を準備する

- アイコン: `references/project-icons.md`の単色/多色分岐に従う
- 画像: `references/project-images.md`のフォーマット判定 → Image方式判定 → 解像度バリエーション → art directionの順で決める

両者ともに、まず`references/project-instructions.md`の該当見出しを確認してください。記載があればそれを最優先します。

実装着手前に、判断結果をユーザーへ提案して承諾を得てください。詳細とescape hatch（承諾省略の条件）は`references/project-icons.md`・`references/project-images.md`の最終Stepを参照します。

## Step 5: スタイルを実装する

`references/project-tokens.md`のCSSフレームワークを特定する手順に従い、マッピングファイルのトークンを実コードへ適用します。

reset CSS・normalize CSS・親要素から継承される値は省略可能です。差分のみを指定します。意図しない継承の混入はStep 6で検証します。

## Step 6: 自己検証サイクル

`references/project-verification.md`の手順で、差分ゼロになるまで反復します。利用可能な比較手法は以下です。

| 手法 | 用途 |
|---|---|
| スクリーンショット目視比較 | 全体の見た目を確認 |
| `getComputedStyle` | CSSプロパティの最終適用値を数値で照合 |
| `getBoundingClientRect` | 表示サイズ・座標をFigma値と数値で照合 |
| Playwright + pixelmatch | スクショ同士のピクセル差分を機械検出 |
| `browser_snapshot`（a11y tree） | DOM構造の見出し・ボタン・ランドマーク階層の妥当性 |

何の差異を疑うか・どの手法で確認するかは`references/project-verification.md`の手順を参照します。

修正があればStep 5に戻り、差分ゼロを確認したらユーザーへ完了報告します。完了報告で触れる項目は`references/project-verification.md`の最終セクションを参照してください。
