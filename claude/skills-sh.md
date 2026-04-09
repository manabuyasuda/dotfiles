# skills.sh

- 公式サイト: [skills.sh](https://skills.sh)
- GitHub: [vercel-labs/skills](https://github.com/vercel-labs/skills)
- 仕様: [agentskills.io](https://agentskills.io)

Vercel Labsが開発・運営するオープンなエージェントスキルのマーケットプレイスおよびCLIツール。スキル仕様は [agentskills.io](https://agentskills.io) で管理されており、Claude Code・Cursor・GitHub Copilotなど[40以上の対応エージェント](https://agentskills.io)へ`npx skills`コマンド1つでインストールできる（対応エージェント数はagentskills.ioの掲載数に基づく）。

## インストール

スキルはエージェントのシステムプロンプトに指示を注入するため、第三者スキルのインストール前には[セキュリティ監査](#セキュリティ監査)セクションを参照すること。

npx経由で実行するためローカルインストールは不要。

```bash
# GitHub リポジトリから（owner/repo 形式）
npx skills add vercel-labs/agent-skills

# ローカルパスから（自作スキルの開発・テスト時）
npx skills add ./my-skill
```

## コマンドリファレンス

### `skills add`

```bash
npx skills add <source> [options]
```

| オプション | 説明 |
|---|---|
| `-g, --global` | プロジェクトではなくユーザーディレクトリへインストール |
| `-a, --agent <agents...>` | 対象エージェントを指定（例: `claude-code`, `cursor`） |
| `-s, --skill <skills...>` | インストールするスキルを名前で指定（`'*'`で全件） |
| `-l, --list` | インストールせずにスキル一覧を表示 |
| `--copy` | シンボリックリンクではなくファイルをコピー |
| `-y, --yes` | 確認プロンプトをスキップ |
| `--all` | 全スキルを全エージェントへインストール |

```bash
# リポジトリ内のスキル一覧を確認
npx skills add vercel-labs/agent-skills --list

# 特定のスキルだけインストール
npx skills add vercel-labs/agent-skills --skill react-best-practices --skill web-design-guidelines

# Claude Code にのみグローバルインストール（-y で確認プロンプトをスキップするため CI でも詰まらない）
npx skills add vercel-labs/agent-skills --skill react-best-practices -g -a claude-code -y
```

### インストール先

| スコープ | フラグ | 保存先（例） | 用途 |
|---|---|---|---|
| プロジェクト | （デフォルト） | `.claude/skills/`・`.agents/skills/`など | リポジトリにコミットしてチームで共有 |
| グローバル | `-g` | `~/.claude/skills/`・`~/.cursor/skills/`など | 全プロジェクトで利用可能 |

保存先のパスはエージェントごとに異なる。エージェント別のパス一覧は [AIコーディングエージェント README](./README.md) を正として参照すること（このドキュメントの表に記載のパスはあくまで例示であり、READMEと食い違う場合はREADMEを優先する）。

デフォルトではシンボリックリンクを作成する（`--copy`を指定するとファイルをコピー）。

シンボリックリンクの実体は`~/.agents/`配下のキャッシュディレクトリに置かれ、その管理情報が`.skill-lock.json`に記録される。`.skill-lock.json`をリポジトリにコミットすれば、他のメンバーが同一スキルを再現できる。

### その他のコマンド

| コマンド | 説明 |
|---|---|
| `npx skills list` | インストール済みスキルを一覧表示 |
| `npx skills find [query]` | マーケットプレイスをキーワード検索 |
| `npx skills check` | スキルの更新確認（更新があれば一覧表示） |
| `npx skills update` | 全スキルを最新版に更新（`check`で確認後に実行するのが安全） |
| `npx skills remove [skills]` | スキルを削除 |
| `npx skills init [name]` | `SKILL.md`テンプレートを生成 |

## .skill-lock.json

`npx skills add`を実行するとプロジェクトルートに`.skill-lock.json`が生成される。
Node.jsの`package-lock.json`と同様に、インストール済みスキルの情報をバージョン固定で記録する。
このファイルをリポジトリにコミットすることで、チームメンバーが同一環境を再現できる。

現行（v3）フォーマットのサンプル。`npx skills add`実行後に生成される実際のファイルはこの形式。

```json
{
  "version": 3,
  "skills": {
    "react-best-practices": {
      "source": "vercel-labs/agent-skills",
      "sourceType": "github",
      "sourceUrl": "https://github.com/vercel-labs/agent-skills",
      "skillFolderHash": "a6a44d5498f7e8f68289902f3dedfc6f38ae0cee1e96527c80724cf27f727c2a",
      "installedAt": "2026-04-08T00:00:00.000Z",
      "updatedAt": "2026-04-08T00:00:00.000Z"
    }
  }
}
```

v1/v2のロックファイル（`"version": 1`または`"version": 2`）がある場合、v3のCLIは自動的にリセットして再インストールを要求する。

### ロックファイルのバージョン履歴

| バージョン | ハッシュフィールド | 説明 |
|---|---|---|
| v1 | `computedHash` | 初期フォーマット |
| v2 | `computedHash` | 中間フォーマット（v1 と同フィールド、内部構造が変更） |
| v3（現行） | `skillFolderHash` | GitHub Trees API から取得したフォルダー全体の SHA。スキルフォルダー内の任意ファイルが変更されると値が変わる |

v2 → v3の移行は後方互換性がなく、v3のCLIがv2以前のロックファイルを読み込んだ場合は自動的にリセットして再インストールを要求する。
（出典: [vercel-labs/skills skill-lock.ts](https://github.com/vercel-labs/skills/blob/main/src/skill-lock.ts) のコードコメント "Bumped from 2 to 3 for folder hash support"）

現行（v3）の`SkillLockEntry`の主なフィールドは以下のとおり。

| フィールド | 型 | 説明 |
|---|---|---|
| `source` | `string` | 正規化されたソース識別子（例: `"owner/repo"`） |
| `sourceType` | `string` | ソースの種別（`github` / `local`など） |
| `sourceUrl` | `string` | インストール時に使用した元 URL |
| `ref` | `string?` | インストールに使用したブランチ・タグ |
| `skillPath` | `string?` | リポジトリ内のサブパス |
| `skillFolderHash` | `string` | GitHub tree SHA（フォルダー全体のハッシュ） |
| `installedAt` | `string` | 初回インストール日時（ISO 8601） |
| `updatedAt` | `string` | 最終更新日時（ISO 8601） |

グローバルロックファイルの保存先は`~/.agents/.skill-lock.json`（`$XDG_STATE_HOME`が設定されている場合は`$XDG_STATE_HOME/skills/.skill-lock.json`）。

## 注目スキル

### vercel-labs/agent-skills

Vercel Labsが公式で管理するスキル集。Webフロントエンド開発に特化したスキルが揃っている。

```bash
npx skills add vercel-labs/agent-skills --list
```

| スキル名 | 説明 |
|---|---|
| `react-best-practices` | React パフォーマンス最適化。8 カテゴリ 40 以上のルール（ウォーターフォール排除・バンドルサイズ最適化など） |
| `web-design-guidelines` | UI 監査スキル。アクセシビリティ・フォーカス状態・フォーム設計など 11 カテゴリ・100 以上のルール |
| `react-native-guidelines` | モバイル開発向け。パフォーマンス・レイアウト・アニメーション対応の 7 セクション・16 ルール |
| `react-view-transitions` | View Transition API を活用したアニメーション実装パターン |
| `composition-patterns` | Boolean prop の乱用を防ぐ Compound Component パターンの指導 |
| `vercel-deploy-claimable` | 40 以上のフレームワークを自動検出してデプロイを実行し、プレビュー URL を返す（外部サービスへの自動操作が発生するため、インストール前に[セキュリティ監査](#セキュリティ監査)での確認を推奨） |

### vercel-labs/next-skills

Next.js固有のスキル集。

```bash
npx skills add vercel-labs/next-skills --list
```

| スキル名 | 説明 |
|---|---|
| `next-best-practices` | Next.js の設計・パフォーマンス・データフェッチのベストプラクティス |
| `next-cache-components` | Next.js キャッシュ戦略とサーバーコンポーネントの最適化 |
| `next-upgrade` | バージョンアップ時の破壊的変更への対応ガイド |

### マーケットプレイスの検索

```bash
# キーワードで検索
npx skills find typescript
npx skills find testing
npx skills find security
```

または [skills.sh](https://skills.sh) でブラウザから検索する。インストール数・トレンドのランキングを確認できる。

## スキルの作成

```bash
# カレントディレクトリに SKILL.md を生成
npx skills init

# サブディレクトリに新しいスキルを生成
npx skills init my-skill
```

作成したスキルはローカルパスを指定してインストール・テストできる。

```bash
# ローカルスキルをテスト用にインストール
npx skills add ./my-skill -a claude-code
```

### マーケットプレイスへの公開

skills.shへの登録手順は公式ドキュメントに記載されていない（2026-04-09時点）。[agentskills.io](https://agentskills.io) または [Discord](https://discord.gg/MKPE9g8aUy) で確認すること。

生成される`SKILL.md`の基本構造。

```markdown
---
name: my-skill
description: このスキルが何をするか、いつ使うかの説明
---

# My Skill

エージェントが従う指示を記述する。

## When to Use

このスキルを使うシナリオを説明する。

## Steps

1. まず〇〇する
2. 次に〇〇する
```

### 内部スキル（非公開）

```markdown
---
name: my-internal-skill
description: 通常は非表示の内部スキル
metadata:
  internal: true
---
```

`INSTALL_INTERNAL_SKILLS=1`を設定した場合のみ表示・インストール可能。

## 環境変数

| 変数 | 説明 |
|---|---|
| `INSTALL_INTERNAL_SKILLS` | `1`または`true`で内部スキルを表示・インストール |
| `DISABLE_TELEMETRY` | 匿名使用テレメトリーを無効化（skills.sh CLIに固有。収集内容の詳細は [vercel-labs/skills README](https://github.com/vercel-labs/skills) を参照） |
| `DO_NOT_TRACK` | テレメトリー無効化の代替方法（複数ツールに共通する汎用的な慣習変数） |

## Claude Code での利用

Claude Codeのスキルは`.claude/skills/`に配置する。

```bash
# Claude Code にのみインストール
npx skills add vercel-labs/agent-skills -a claude-code

# グローバルインストール（全プロジェクトで使用可能）
npx skills add vercel-labs/agent-skills -g -a claude-code
```

[Claude Code Skills ドキュメント](https://docs.anthropic.com/ja/docs/claude-code/skills-overview)（リンク先が変更されている場合はAnthropic公式ドキュメントで "Claude Code skills" を検索する）

---

## セキュリティ監査

スキルはエージェントのシステムプロンプトに指示を注入する仕組みのため、第三者による悪意あるスキルがプロンプトインジェクションの攻撃ベクターになり得る。

*情報確認日: 2026-04-08*

### 公開モデルとリスク

skills.shは誰でもGitHubリポジトリを公開すればリストされる（npmやGitHub Actions Marketplaceに近い構造）。人手による審査はない。

Gen Threat Labsの調査（2026年2月）では、観測された自律AIエージェントのスキルの約15% に悪意あるインストラクションが含まれていた（[出典: Gen launches Agent Trust Hub — PR Newswire, 2026-02-04](https://www.prnewswire.com/news-releases/gen-launches-agent-trust-hub-for-safer-agentic-era-302679016.html)）。なお、この調査はskills.shではなくOpenClaw（オープンソースの自律AIエージェントプラットフォーム）上のスキルを対象としたものであり、標本数・調査期間は非公開。

### [skills.sh/audits](https://skills.sh/audits) — 3つの自動スキャン

3つの外部ツールによる自動スキャン結果が公開されている。いずれも自動スキャンであり、人手によるレビューではない。

| ツール | 観点 | 表示形式 |
|---|---|---|
| **Gen Agent Trust Hub** | プロンプト（インストラクション）の悪意 | Safe / Med Risk / Critical |
| **Socket** | パッケージの振る舞い（未知の脅威） | N alerts |
| **Snyk** | 依存関係の既知脆弱性（CVE） | Low / Med / High / Critical Risk |

#### Gen Agent Trust Hub

Gen Digital（Norton・Avast等を擁する企業）が2026年2月にローンチ。3つの中で唯一プロンプトレベルの悪意を検出する。

ルールセットは非公開（内部判定基準はブラックボックス）だが、公式プレスリリースおよび類似ツールの一般的な観点から次のカテゴリが検出対象と推定される。

- SKILL.md内のプロンプトインジェクション（「前の指示を無視しろ」系）
- エージェントにデータを外部送信させるデータ窃取指示
- 任意の名前の実行スクリプト（`post_install.sh`等）でのサイレントなコード実行
- スキルの説明と実際の振る舞いの不一致
- エージェントのアイデンティティを書き換えるインストラクション

#### Socket

CVEになっていない未知の悪意ある振る舞いを検出する。パッケージの振る舞い（install scripts・network access・filesystem access・shell execution・難読化コード等）を静的解析する。

実用的な見方は次のとおり。

- 0 alerts — 気にしなくていい
- 1+ alerts — スキルのSecurity Auditsページでalertの種類を確認し、そのスキルの機能として妥当かを判断する。妥当でない場合はインストールしない
- とくに`install scripts` + `network access`の組み合わせは要注意（インストール時に外部サーバーへデータを送信するパターン）

#### Snyk

リポジトリの依存関係に含まれる既知の脆弱性をCVSSスコアで評価する。

| 深刻度 | CVSS スコア |
|---|---|
| Critical | 9.0〜10.0 |
| High | 7.0〜8.9 |
| Medium | 4.0〜6.9 |
| Low | 0.1〜3.9 |


### スキル導入前のチェックリスト

リスクを排除できない場合はインストールしない。auditsの結果が許容できない、または内容が理解できない場合も同様。

#### 1. 提供元を確認する

[skills.sh/official](https://skills.sh/official) はAnthropic・Google・Microsoft等の技術提供元企業が直接公開するスキル集で、一定の信頼性がある。個人リポジトリのスキルはより慎重に確認すること。

#### 2. スキルの詳細ページで自動スキャン結果を確認する

スキルの詳細ページにあるSecurity Auditsセクションで確認する。

| ツール | 確認内容 |
|---|---|
| **Gen Agent Trust Hub** | Critical はインストール中止。Med Riskも内容を確認する（ルールセットは非公開のため判定根拠の検証は難しい） |
| **Socket** | 1+ alerts はalertの内容を確認し、スキルの機能として妥当かを判断する。`install scripts` + `network access`の組み合わせは要注意 |
| **Snyk** | すべて内容を確認する。High / Critical は許容できなければインストール中止 |

[skills.sh/audits](https://skills.sh/audits) にはスキルの一覧とそれぞれのAuditsの結果が確認できる。スキルを探すときや、全体的なセキュリティの傾向を確認するときに使える。

auditsに未登録のスキルはステップ3・4が唯一の確認手段となる。

#### 3. SKILL.mdを自分で読む

Genの自動スキャンでプロンプトレベルの悪意はある程度検知できる。確実性を高めたい場合は直接読む。スキルはSKILL.md以外にスクリプトやアセットを含む場合があるため、リポジトリのファイル構成も確認する。

- **指示の範囲** — スキル名・説明に書かれた用途を超える指示（ファイル操作・ネットワーク通信・設定変更等）が含まれていないか
- **プロンプトインジェクション** —「前の指示を無視しろ」「システムプロンプトを書き換えろ」のような命令が含まれていないか
- **外部通信の指示** — 特定のURLへの情報送信を促す記述がないか
- **同梱スクリプト** — SKILL.md以外にシェルスクリプトや実行可能ファイルが含まれていないか
- **提供元の信頼性** — 公式組織か、個人リポジトリか。個人リポジトリの場合はコミット履歴・スター数・最終更新日を確認する

#### 4. インストール後に注入内容を確認する

インストールされたスキルは各エージェントのスキルディレクトリに配置される（[AIコーディングエージェント README](./README.md) のパス一覧を参照）。

```bash
# 例: Claude Codeのスキルディレクトリを確認
ls -la .claude/skills/
cat .claude/skills/react-best-practices.md
```

#### チームでの運用

`npx skills add`や`npx skills update`を実行すると`.skill-lock.json`が更新される。このファイルの変更をPRに含めることで、レビュー時にスキルの追加・変更を把握し審査できる。
