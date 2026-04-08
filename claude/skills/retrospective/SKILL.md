---
name: retrospective
description: >
  セッションのふりかえりをKPTA形式で実施し、設定の改善提案と即時実施を行う。
  「ふりかえり」「レトロスペクティブ」「retrospective」「振り返り」「KPT」「KPTA」
  「今日のセッションを振り返って」「改善提案して」のように使う。
context: fork
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - AskUserQuestion
  - Agent
---

# retrospective

セッションを振り返り、「今すぐ直せる設定変更」を提案・実施する。
記録は副産物。メインは改善の実施。

1. retrospectiveファイルを読み込む
2. セッション内容を整理する
3. KPTA分析
4. 改善提案を生成する
5. 改善を実施する
6. retrospectiveファイルにT/Aと結果を追記する

---

## Step 1: retrospective ファイルを読み込む

セッションで使われたretrospectiveファイルを読み込む。
最後に更新されたファイルを使う（セッションが日をまたぐ場合も対応）。

```bash
latest=$(ls -t retrospective/[0-9]*.md 2>/dev/null | head -1)
cat "$latest" 2>/dev/null || echo "(記録なし)"
```

---

## Step 2: セッション内容を整理する

会話コンテキストとretrospectiveファイルを振り返り、以下の観点で気づきを拾う。

| 観点 | 確認内容 |
|---|---|
| 繰り返しのブロック | 同じ deny / ask が複数回発生したか |
| 繰り返しの承認 | 同じ permission を何度も許可したか |
| 繰り返しの指示 | 同じ指示・判断基準を複数回伝えたか |
| 定型化したワークフロー | 毎回同じ手順で作業したか |
| 手動で繰り返し呼んだスキル | 同じスキル・エージェントを毎回手動で実行したか |
| 新ツール導入 | 新しいコマンド・サービスを使い始めたか |
| 遅いフィードバック | CI のみになっているチェックがあるか |
| うまくいった判断 | 続けるべき良いアプローチがあったか |

実施したタスクの概要と、上記の観点で見つかった改善候補をユーザーに提示して確認を取る。

---

## Step 3: KPTA分析

| カテゴリ | 着眼点 |
|---|---|
| **Keep** | 続けるべき良い判断・アプローチ（さらに強化・仕組み化できるものはTry/Actionへ） |
| **Problem** | Step 2 の気づきから原因を掘り下げる |
| **Try** | 改善につながりそうなアイデア（量重視） |
| **Action** | 次のセッションで確実に実行できる具体的な施策 |

Problemの各項目は以下のフォーマットで整理する。改善先はStep 4の判断テーブルを参照する。

```
### [P-N] タイトル
- 状況: いつ・どこで何が起きたか
- 問題: 何がどうなってしまったか
- 原因: 何が再現条件か
- 改善先: hooks / CLAUDE.md / rules / skills / settings.json / agents
- 対策: 改善先に対して何をどう変えるか
```

---

## Step 4: 改善提案を生成する

Step 3のProblem（改善先・対策）をもとに、具体的なファイルパスと変更内容を決める。

#### 改善先の判断に迷ったとき

| 症状 | 改善先 |
|---|---|
| 同じ deny / ask が複数回発生した | `hooks/pre-tool-use/` にルールを追加 |
| 編集してはいけないファイル（設定・鍵・lockファイル等）が file-protect.sh に漏れていて編集された | `hooks/pre-tool-use/file-protect.sh` にパターン追加 |
| 同じ permission を何度も承認した | `settings.json` の allow に昇格 |
| すべての会話に共通する制約（短く書ける） | `CLAUDE.md` に追記 |
| 特定のファイル種別を編集するときだけ必要 | `rules/` に追加（paths: で適用範囲を絞る） |
| 毎回同じ手順・明示的に呼び出す | `skills/` に切り出す（`/skill-creator` を使う） |
| 状況で判断が変わる・自律的に動かす | `agents/` に切り出す |
| 新しいツール・サービスを使い始めた | `settings.json` の allow/deny に追加 |
| フィードバックが遅い・CI のみになっている | `hooks/post-tool-use/` に移す |
| スキル・エージェントを毎回手動で呼び出している | `UserPromptSubmit` フックで自動化できないか検討する |

### 改善提案のフォーマット

```
#### [改善提案-N] タイトル

- 対象: hooks / CLAUDE.md / rules / skills / settings.json / agents
- 対象ファイル: 具体的なパス
- 内容: 何をどう変更・追加するか
- メリット: この改善によって何が変わるか
- デメリット: 制約・副作用・注意点
```

---

## Step 5: 改善を実施する

AskUserQuestionで確認する。

```json
{
  "question": "改善提案の中で、このセッション中に実施するものを選んでください",
  "options": [
    { "label": "実施する", "description": "どの提案を実施するか選んで今すぐ実装する" },
    { "label": "記録のみ", "description": "retrospective ファイルに記録して次回以降に持ち越す" }
  ]
}
```

「実施する」が選択された場合、以下を直接実行する。

| 改善対象 | 実施方法 |
|---|---|
| hooks にルール追加 | 対象ファイルを編集 |
| CLAUDE.md / rules/ に追記 | 該当ファイルを編集 |
| 新スキル作成 | `/skill-creator` を呼び出す |
| settings.jsonのallow昇格 | `settings.json` を編集 |

---

## Step 6: retrospective ファイルに T/A と結果を追記する

`retrospective/YYYY-MM-DD.md` にTry/Actionと実施結果を追記する（ファイルがなければ作成）。

```markdown
## Try
- <箇条書き>

## Action
<Step 3 の Action 項目>

## 改善提案と実施結果
<Step 4・5 の内容と実施結果>
```

---

## 注意事項

- Keepは改善だけでなく「良かった点の言語化」も重要
- Problemは責めるのではなく「再現条件を探す」姿勢で書く
- Actionは「今すぐできる」「誰が見ても明確」な粒度に絞る
- CLAUDE.mdの変更は100行以内を維持する
