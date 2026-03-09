# Claude Code

Anthropic製のAIコーディングアシスタントCLI。ターミナルから直接Claudeと対話しながらコードの編集・実行・デバッグ・Git操作を行える。

## インストール

```bash
npm install -g @anthropic-ai/claude-code
```

`nodenv/default-packages`で自動インストールされる。

## 基本的な使い方

```bash
# 対話モードで起動
claude

# 隔離された git worktree 上で起動（WorktreeCreate フックが呼ばれる）
claude --worktree <branch-name>
claude -w <branch-name>

# 1回限りのプロンプトを実行して終了
claude -p "このコードをレビューして"

# 特定のディレクトリで起動
claude /path/to/project
```

## 主要オプション

| オプション | 説明 |
|---|---|
| `--worktree <branch>`, `-w` | 新しい git worktree を作成して Claude を起動する |
| `--print`, `-p` | 1回限りのプロンプトを実行して終了する（非対話モード） |
| `--model <model>` | 使用するモデルを指定する |
| `--no-auto-updater` | 自動更新を無効にする |
| `--version` | バージョンを表示する |

## 設定ファイル

| パス | 説明 |
|---|---|
| `~/.claude/settings.json` | グローバル設定（モデル・hooks・plugins） |
| `~/.claude/CLAUDE.md` | グローバル指示（全プロジェクト共通の指示） |
| `.claude/settings.json` | プロジェクト固有の設定 |
| `CLAUDE.md` | プロジェクト固有の指示 |

## Hooks

Claude Codeのイベントに応じてシェルコマンドを実行できる仕組み。`settings.json`に設定する。

| イベント | 説明 |
|---|---|
| `WorktreeCreate` | `--worktree` でワークツリーを作成するときに呼ばれる。stdout に返したパスに Claude が切り替わる |
| `WorktreeRemove` | `--worktree` セッション終了時に "remove" を選択したときに呼ばれる |
| `PreToolUse` | ツール実行前に呼ばれる。ブロックすることも可能 |
| `Notification` | 通知イベント（`permission_prompt` / `idle_prompt` / `stop`）が発生したときに呼ばれる |

このリポジトリのhooksは`~/.claude/hooks/`に配置されている。

## スラッシュコマンド（対話中）

| コマンド | 説明 |
|---|---|
| `/help` | ヘルプを表示する |
| `/clear` | 会話履歴をクリアする |
| `/compact` | 会話を要約してコンテキストを節約する |
| `/cost` | 現在のセッションのトークン使用量と費用を表示する |

## AWS Bedrockで使う

Claude CodeはAWS Bedrock経由でも利用できる。設定はdotfilesで管理せず、`~/.zshrc.local` に書く。

### セットアップ手順

**1. AWSプロファイルを設定する**

`~/.aws/config` にプロファイルとリージョンを設定し、`~/.aws/credentials` にアクセスキーを設定する。

```bash
# ディレクトリとファイルの存在を確認
ls ~/.aws/config ~/.aws/credentials

# なければディレクトリとファイルを作成
mkdir -p ~/.aws
touch ~/.aws/config ~/.aws/credentials
```

作成後、エディターで各ファイルに以下を追記する。`<aws-profile-name>`は以降の設定で同じ値を指定していれば、どのような値を使用しても問題ない。

```ini
# ~/.aws/config
[profile <aws-profile-name>]
region = us-east-1
```

```ini
# ~/.aws/credentials
[<aws-profile-name>]
aws_access_key_id = <アクセスキーID>
aws_secret_access_key = <シークレットアクセスキー>
```

アクセスキーはAWSコンソールの「IAM > ユーザー > セキュリティ認証情報」から発行する。SSO経由の場合は `aws sso configure` で設定する（AWS CLIが必要。未インストールの場合は `brew install aws-cli`）。

設定後、認証情報が正しく読み込まれているか確認する（AWS CLIが必要）。

```bash
aws sts get-caller-identity --profile <aws-profile-name>
```

以下のようにJSONが返れば認証成功。

```json
{
    "UserId": "AIDA...",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/<username>"
}
```

Bedrockコマンドを実行して以下のような `AccessDeniedException` が返った場合も、エラー文中にIAMユーザーのARNが含まれていれば**認証自体は成功**している。

```
An error occurred (AccessDeniedException) when calling the ... operation:
User: arn:aws:iam::123456789012:user/<username> is not authorized to perform: ...
```

Claude CodeはBedrockの `InvokeModel` 権限があれば動作する。権限が不足している場合はAWS管理者に依頼する。

**2. `~/.zshrc` に `~/.zshrc.local` の読み込みを追加する**

```bash
# local overrides (not tracked in dotfiles)
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local
```

`[[ -f ~/.zshrc.local ]]` でファイルの存在を確認してから `source` するため、ファイルがなくてもエラーにならない。

**3. `~/.zshrc.local` を作成して環境変数を設定する**

```bash
# ファイルが存在するか確認
ls ~/.zshrc.local

# なければ作成（あれば既存ファイルに追記）
cat >> ~/.zshrc.local <<'EOF'

# for claude code (AWS Bedrock)
export CLAUDE_CODE_USE_BEDROCK=1
export AWS_REGION=us-east-1
export AWS_PROFILE=<aws-profile-name>
export ANTHROPIC_MODEL=arn:aws:bedrock:us-east-1:<account-id>:inference-profile/us.anthropic.claude-sonnet-4-6
export ANTHROPIC_SMALL_FAST_MODEL=arn:aws:bedrock:us-east-1:<account-id>:inference-profile/global.anthropic.claude-haiku-4-5-20251001-v1:0
EOF
```

**4. 設定を反映する**

```bash
source ~/.zshrc.local
```

### 環境変数の説明

| 変数名 | 値 | 説明 |
|---|---|---|
| `CLAUDE_CODE_USE_BEDROCK` | `1` / `0` | Claude Code独自のフラグ。`1`でBedrock経由、`0`でAnthropicAPI直接。AWS設定に関係なく常にこの値で動作が切り替わる |
| `AWS_REGION` | リージョン名 | Bedrockのリージョン。ARNに含まれるリージョンと合わせる必要がある |
| `AWS_PROFILE` | プロファイル名 | `~/.aws/credentials` に設定したプロファイル名 |
| `ANTHROPIC_MODEL` | ARN文字列 | メインモデル（重いタスクに使用） |
| `ANTHROPIC_SMALL_FAST_MODEL` | ARN文字列 | 軽量・高速モデル（補助的な処理に使用） |

### ARNとは

ARN（Amazon Resource Name）はAWSリソースを一意に識別する文字列。

```
arn:aws:bedrock:us-east-1:123456789012:inference-profile/us.anthropic.claude-sonnet-4-6
               └─リージョン┘└─アカウントID─┘ └────────────リソース種別/ID──────────────┘
```

ARNはAWSコンソールの「Amazon Bedrock > 推論プロファイル」から確認できる。

## VS CodeでBedrockを使う

ターミナルで設定した環境変数はVS CodeのClaude Code拡張には引き継がれない。VS Codeからも使う場合は、ユーザー設定（`~/Library/Application Support/Code/User/settings.json`）に以下を追加する。

```json
"claudeCode.environmentVariables": [
    {
        "name": "CLAUDE_CODE_USE_BEDROCK",
        "value": "1"
    },
    {
        "name": "AWS_PROFILE",
        "value": "<aws-profile-name>"
    }
]
```

## BedrockとMaxプランをAliasで切り分ける

デフォルトをBedrockにした上で、個人のMaxプランへ切り替えるエイリアスを `~/.zshrc.local` に追加する。

```bash
# デフォルト（Bedrock）は環境変数で設定済みのため追加エイリアス不要
# claude コマンドで直接起動できる

# 個人のMaxプラン（Anthropic直接）で起動するエイリアス
alias cc-my="CLAUDE_CODE_USE_BEDROCK=0 ANTHROPIC_MODEL= ANTHROPIC_SMALL_FAST_MODEL= AWS_PROFILE= claude"
```

`cc-my` はBedrockに関する環境変数を空にして上書きすることで、AnthropicのAPIに直接繋ぎMaxプランを使う。ウェルカム画面に `Claude Max` と表示されれば切り替え成功。

### エイリアス名の安全確認

`cc`（Cコンパイラ）など既存のコマンド名をエイリアスにすると、Claude Code内部がサブプロセスを起動するときにシェルエイリアスが解決されず、意図しないコマンドが実行される危険がある。エイリアス名を決める前に以下で衝突しないか確認する。

```bash
# PATHに同名の実行ファイルが存在しないか確認
which <alias-name>

# シェルビルトイン・エイリアス・外部コマンドすべてを確認
type <alias-name>
```

`which` が何も返さず、`type` が "not found" であれば安全に使える。`cc-` のようなプレフィックスを付けるとシステムコマンドとの衝突を避けやすい。

## 参考リンク

- [Claude Code 公式ドキュメント](https://docs.anthropic.com/ja/docs/claude-code/overview)
- [npm - @anthropic-ai/claude-code](https://www.npmjs.com/package/@anthropic-ai/claude-code)
- [Amazon Bedrock - Claude Code設定](https://docs.anthropic.com/ja/docs/claude-code/amazon-bedrock)
