# dotfiles

macOS環境の設定ファイルを管理するリポジトリです。シンボリックリンク方式で、実ファイルをこのリポジトリ内に置き、ホームディレクトリからリンクを張ります。

## ディレクトリ構造

```
dotfiles/
├── setup.sh              # セットアップスクリプト（シンボリックリンク作成）
├── macos.sh              # macOS設定の自動適用スクリプト
├── Brewfile              # Homebrewパッケージ一覧
├── zsh/
│   ├── .zshrc            # シェル設定（mise, direnv, PATH）
│   ├── .zprofile         # ログインシェル設定（Homebrew）
│   └── .zshenv           # 全シェル共通の環境変数
├── git/
│   └── .gitconfig        # Gitのグローバル設定
├── mise/
│   └── config.toml       # miseで管理する言語ランタイム・ツール定義
├── gh/
│   └── extensions        # gh拡張機能一覧
├── claude/
│   ├── CLAUDE.md         # グローバル指示
│   ├── settings.json     # Claude Code設定
│   ├── skills/           # カスタムスキル
│   └── hooks/            # フック設定
└── docs/
    └── tools/            # 開発ツールのドキュメント
```

## Macの初期化

調子が悪い場合や、新しいMacへ移行する前の既存Macの整理時に実施します。初期化後は「新しいマシンでのセットアップ」に従います。

参考: [Macを消去して出荷時の設定にリセットする - Apple公式](https://support.apple.com/ja-jp/102664)

### 事前準備

1. 重要なデータをバックアップします（Time Machineまたはクラウド・外付けディスクへ手動コピー）
   - Raycast — Advanced → ExportでDropboxに設定ファイルをエクスポートします
2. Apple IDをサインアウトします（システム設定 → Apple ID → サインアウト）
   - Find My Macが有効な場合、サインアウトせずに初期化するとアクティベーションロックが残り、初期化後の再セットアップ時にApple IDとパスワードの入力が必要になります
   - 「すべてのコンテンツと設定を消去」を使う場合はウィザードがサインアウトまで誘導するため、事前の手動対応は不要です
   - 売却・譲渡・貸与PCの返却時は必須です（サインアウトしないと次の所有者がMacを使えなくなります）
3. Bluetoothデバイスのペアリングを解除します
   - 自分で再使用する場合は不要です。Mac側のペアリング情報は初期化で消えるため、初期化後にデバイス側から再ペアリングすれば問題ありません
   - 売却・譲渡・貸与PCの返却時は推奨です（デバイス側に情報が残り、相手が同じデバイスを使っている場合に誤接続のリスクがあります）

### 初期化

#### macOS 12 Monterey以降（Apple SiliconまたはT2チップ搭載Mac）

システム設定 → 一般 → 転送またはリセット → すべてのコンテンツと設定を消去

#### 上記が使えない場合（復元モード）

- Apple Silicon: 電源ボタンを長く押して「オプション」を選択します
- Intel Mac: 再起動して`Command + R`を長く押します

復元モード内で次を実施します。

1. Disk Utility → Macintosh HDを選択して消去します（APFS形式）
2. macOSを再インストールします

## 新しいマシンでのセットアップ

### macOSのセットアップウィザード

macOSのセットアップウィザードにしたがって、Wi-Fiへ接続し、Apple IDでサインインします。

### 初期設定

#### 1. SafariでNotionにログインする

各種情報を参照するため、最初に開いておきます。

#### 2. HHKBを新しいMacにBluetoothでペアリングする

キーマップやペアリング情報はキーボード本体に保存されるため、新しいMacで必要な作業はペアリングだけです。キー操作の詳細は[取扱説明書（PDF）](https://origin.pfultd.com/downloads/hhkb/manual/P3PC-6651-01.pdf)を参照してください。

1. キーボードの電源スイッチを長押し（1秒以上）して電源を入れます
2. `Fn + Q`を押してペアリング待機モードにします
3. `Fn + Control + 数字キー（1〜4）`を押して登録先のスロットを指定します。スロット1を自宅用のMac、スロット2以降を案件用のマシンに割り当てます
4. Mac側のBluetooth設定で「HHKB-Hybrid_n」（nはスロット番号）を選び、表示されたペアリング用の数字を入力します
5. 「キーボードの種類を選択」が出たら「JIS（日本語）」を選びます

次はセットアップ手順では不要ですが、定期的に必要になる操作です（設定はキーボード本体に保存されます）。

- 接続先の切り替え: `Fn + Control + 数字キー（1〜4）`で登録済みのスロットを切り替えます
- USB Type-C接続への切り替え: `Fn + Control + 0`で切り替えます。ファームウェア更新時はBluetoothではなくUSB接続が必要なため、先にこの操作をします
- ファームウェアの更新: [HHKBキーマップ変更ツール](https://happyhackingkb.com/jp/download/#keymap)のメニュー「ヘルプ → 更新プログラムの確認 → HHKBファームウェア」で最新版が出たら`.hfb`ファイルをダウンロードし、「キーボードファームウェア更新」から適用します

#### 3. 外部ディスプレイとマウスを設定する

Macの詳細設定は後の手順で行うため、ここでは作業しやすくするための最小限の設定にとどめます。

- システム設定 → ディスプレイ → 配置で外部モニターを主ディスプレイに設定します
- 解像度を変更します（27インチ4Kの場合は3008×1692）
- マウスを接続し、システム設定 → マウスで速度を最大に設定します

### 開発環境の構築

#### 4. Command Line Toolsをインストールする

```bash
xcode-select --install
```

#### 5. Claude Codeをインストールする

mise管理下には置かず、公式ネイティブインストーラーで導入します（npm版は非推奨です。自動更新がmiseのshimsと競合するため）。`curl`だけで入り、Homebrewやmiseに依存しません。先に入れておくと、以降の手順でClaudeに相談しながら進められます。

```bash
curl -fsSL https://claude.ai/install.sh | bash
```

インストーラーは本体バイナリ（約200MB）を進捗表示なしでダウンロードします。実行後しばらく無反応に見えますが、これは正常な挙動なので`Ctrl+C`で中断しないでください。回線次第で数分かかります。完了を待つ間は別のターミナルタブでステップ6（Homebrew）以降を進めて構いません。進捗を確認したい場合は、別タブで次のコマンドを繰り返します（サイズが増えていればダウンロード中です）。

```bash
ls -l ~/.claude/downloads/
```

完了すると`~/.local/bin/claude`に配置されます。この時点ではPATH優先設定がまだ効かないため、フルパスで動作確認します（旧版が残っている場合のシャドウ回避のため、初回は必ずフルパスで叩きます）。

```bash
~/.local/bin/claude --version
~/.local/bin/claude doctor
```

ステップ7のdotfiles適用後は`.zshrc`/`.zshenv`で`~/.local/bin`がmiseのshimsより前に来るため、ネイティブ版が優先されます。ネイティブ版が自動更新を担うため、`DISABLE_AUTOUPDATER`等は設定しません。

> [!NOTE]
> 旧npm版からの一度きりの移行（既存マシンのみ）
>
> 過去に`npm install -g @anthropic-ai/claude-code`で入れていた場合、ネイティブ版が動作確認できてから次で旧版を撤去します。`nodenv`環境だったときは撤去後に`nodenv rehash && hash -r`を実行します（mise移行後は不要）。最後に`which claude`が`~/.local/bin/claude`を指せば完了です。
> ```bash
> npm uninstall -g @anthropic-ai/claude-code
> ```

#### 6. [Homebrew](https://brew.sh/ja/)をインストールする

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Apple Siliconの場合、インストール完了時にPATHを通すコマンドの案内が表示されます。案内にしたがって次を実行します（`.zprofile`への追記はステップ7でdotfilesのsymlinkに置き換わりますが、現在のシェルへ反映するためここで実行します）。

```bash
echo >> ~/.zprofile
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
eval "$(/opt/homebrew/bin/brew shellenv)"
```

#### 7. ディレクトリを作成してdotfilesをセットアップする

作業ディレクトリはホーム直下に作ります。`MY`は個人リポジトリ、`PROJECT`は案件リポジトリ、`Screenshot`はスクリーンショットの保存先です。`~/Documents`配下は避けます（iCloud同期の対象だとコピーが遅くなったり、rebase実行時に不要なファイルが生成されたりするため）。クローンはSSH設定前のためHTTPSを使います。

```bash
mkdir -p ~/MY ~/PROJECT ~/Screenshot
git clone https://github.com/manabuyasuda/dotfiles ~/MY/dotfiles
brew bundle install --file=~/MY/dotfiles/Brewfile --verbose
```

インストールの途中で、アプリ（cask）によってはパスワードを求められる場合があります。`brew bundle install`が完了すると、次のように表示されます。

```
Homebrew Bundle complete! XX Brewfile dependencies now installed.
```

`brew bundle install`の完了後、続けて次を実行します（`setup.sh`はインストール完了直後に実行できます）。

```bash
cd ~/MY/dotfiles && ./setup.sh
mise trust ~/.config/mise/config.toml
mise install node
mise install
mise exec -- npm ci
```

`brew bundle install`と`mise install`はどちらも時間がかかります。完了を待つ間、依存関係のないステップ8（SSH鍵）・9（フォント）・11（macOS設定）を並行して進められます。

`setup.sh`は次を実行します。何度実行しても安全です（冪等）。

- 既存ファイルを`~/.dotfiles_backup/`にバックアップしてからシンボリックリンクを作成します
- `gh/extensions`に記載されたgh拡張機能をインストールします

`mise install`の各行は次の理由によります。

- `mise trust`は、カレントディレクトリのリポジトリ内にある`mise/config.toml`がローカル設定として検出され、未信頼のままでは読み込めないために実行します。
- `node`を先に単体で導入するのは、`npm:`バックエンドのツール（`mermaid-cli`など）がバージョン解決に`npm`を必要とするためです。`node`がない状態で`mise install`を実行すると`npm:*`の解決が`No such file or directory`で失敗します。
- `pnpm`はmiseのバックエンドがGitHubのリリースから取得するため、回線によっては取得に数分かかります。無反応に見えても中断せず完走させてください。

`npm ci`の実行時に`prepare`スクリプトが走り、lefthookが`.git/hooks/pre-commit`を配置します。これによりステージ済みの`.md`ファイルへtextlintが自動で走り、違反があるとコミットが止まります。詳細は「[textlintとpre-commitフック](#textlintとpre-commitフック)」を参照してください。

#### 8. SSH鍵を設定してGitHubに登録する

GitHubアカウントごとに鍵とホストエイリアスを分けて管理します。個人アカウントは`my`、案件・会社アカウントは案件名など任意のプレフィックスをホスト名に付けます。

##### 個人アカウント用の鍵を作成する

鍵を生成し、macOSキーチェーンに登録します（再起動後もパスフレーズ入力が不要になります）。続けて公開鍵をクリップボードにコピーし、開いたページで個人GitHubアカウントに登録します。

```bash
ssh-keygen -t ed25519 -f ~/.ssh/my_id_ed25519
ssh-add --apple-use-keychain ~/.ssh/my_id_ed25519
pbcopy < ~/.ssh/my_id_ed25519.pub
open https://github.com/settings/ssh/new
```

##### 案件・会社アカウント用の鍵を作成する（アカウントごとに繰り返す）

次はテンプレートです。`<prefix>`を案件名や会社名（`acme`など。ホスト名は`acme.github.com`になります）に置き換えてから実行します。

```bash
ssh-keygen -t ed25519 -f ~/.ssh/<prefix>_id_ed25519
ssh-add --apple-use-keychain ~/.ssh/<prefix>_id_ed25519
pbcopy < ~/.ssh/<prefix>_id_ed25519.pub
open https://github.com/settings/ssh/new
```

##### `~/.ssh/config`を作成する

個人アカウント分は固定なので、次のコマンドで作成します。

```bash
mkdir -p ~/.ssh && chmod 700 ~/.ssh
cat >> ~/.ssh/config <<'EOF'
# 個人アカウント
Host my.github.com
  HostName github.com
  AddKeysToAgent yes
  UseKeychain yes
  IdentityFile ~/.ssh/my_id_ed25519
  IdentitiesOnly yes
EOF
chmod 600 ~/.ssh/config
```

案件・会社アカウントを使う場合は、`~/.ssh/config`に次のブロックをプレフィックスごとに追記します。

```
# 案件・会社アカウント（アカウントごとに追加する）
Host <prefix>.github.com
  HostName github.com
  AddKeysToAgent yes
  UseKeychain yes
  IdentityFile ~/.ssh/<prefix>_id_ed25519
  IdentitiesOnly yes
```

`IdentitiesOnly yes`はSSHエージェントに他の鍵が読み込まれていても、指定した鍵のみを使うようにする設定です。複数アカウントの混線を防ぐために必須です。

##### 接続を確認する

```bash
ssh -T git@my.github.com
```

`Hi <個人アカウント名>! You've successfully authenticated...`と表示されれば成功です。案件アカウントは`ssh -T git@<prefix>.github.com`（`<prefix>`は設定したホスト名）で同様に確認します。

##### dotfilesのリモートURLをSSHに変更して個人リポジトリをクローンする

SSHが使えるようになったので、次を実行します。

```bash
git -C ~/MY/dotfiles remote set-url origin git@my.github.com:manabuyasuda/dotfiles.git
git clone git@my.github.com:manabuyasuda/manabuyasuda ~/MY/manabuyasuda
git clone git@my.github.com:manabuyasuda/knowledge-base.git ~/MY/knowledge-base
```

##### 案件リポジトリをクローンする場合

`<prefix>`・`<org-or-user>`・`<repo>`を実際の値に置き換えて実行します。

```bash
git clone git@<prefix>.github.com:<org-or-user>/<repo>.git ~/PROJECT/<repo>
```

Homebrew・dotfiles・SSHまでの手動セットアップはここまでです。シェルを読み込み直すとmiseが有効になり、`~/.local/bin`がshimsより前に来るので`which claude`はネイティブ版を指します。あとはVS Codeでdotfilesを開き、ステップ5で入れたClaude Codeに「ステップ9以降を進めて」と依頼すれば、残りのセットアップを任せられます。

```bash
exec $SHELL -l
which claude
code ~/MY/dotfiles
claude
```

#### 9. フォントをインストールする

Noto Sans JPはBrewfileからインストール済みです。Source Code Proはコマンドで手動インストールします。

```bash
curl -LO https://github.com/adobe-fonts/source-code-pro/archive/release.zip
unzip release.zip
cp -a source-code-pro-release/TTF/* ~/Library/Fonts
rm -rf release.zip source-code-pro-release
```

### アプリの設定

#### 10. 各アプリを設定する（Notionを参照）

brewでインストールしたアプリはFinderから1つずつ起動して設定を進めます。アクセシビリティやファイルアクセスなど、セキュリティに関する許可を求められるため、1つずつ確認しながら進めるとわかりやすくなります。

### Macの設定

#### 11. `macos.sh`を実行してシステム設定を一括適用する

```bash
~/MY/dotfiles/macos.sh
```

次は手動で設定します。

##### 一般 → ログイン項目（ログイン時に開く）

- BetterTouchTool、CotEditor、DeepL、Dropbox、Google Chrome、MeetingBar、Notion、PopClip、Raycast、Slack、Sourcetree、Visual Studio Code

##### 通知（通知を許可する）

- MeetingBar、ターミナル、Slack

##### コントロールセンター（メニューバー）

- Spotlight：メニューバーに表示しません

##### キーボード → キーボードショートカット

- Spotlight：すべてオフ（Raycastを使用するため）
- 入力ソース（前の入力ソースを選択）：オフ
- 「次のウィンドウを操作対象にする…」を選択し、ショートカットの表示をクリックしてから設定したいショートカットを入力します

##### キーボード → 入力ソース → 日本語

- 入力モード：英字にチェックを入れます
- タイプミスを修正：オフ
- Windows風のキー操作：オン
- 数字を全角入力：オフ

##### キーボード → 入力ソース → ABCを削除する

##### iCloud → iCloudに保存済み → すべて見る

- 写真：クリックして「このMacを同期」のチェックを外し、「Macから削除」を選びます

#### 12. Macを再起動する

ひととおりの設定が完了したら再起動します。システム設定の変更が反映され、アプリの許可ダイアログなどが表示されます。

## 運用

### 設定ファイルを編集した場合

シンボリックリンク経由なので、`~/.zshrc`などを直接編集すればリポジトリ内のファイルが更新されます。

```bash
cd ~/MY/dotfiles
git diff
git add -A && git commit -m "chore: 変更内容"
```

### Brewfileを更新する場合

```bash
brew bundle dump --file=~/MY/dotfiles/Brewfile --force
```

### Claude Codeの設定を追加する場合

`claude/`ディレクトリ（`skills/`, `hooks/`）はディレクトリごとシンボリックリンクされているため、中にファイルを追加すると自動的にリポジトリに反映されます。

`keybindings.json`など新しい個別ファイルを追加する場合は、`claude/`に作成してから`./setup.sh`を再実行します。

### Claude Code Update Watch

Claude Codeの新バージョンを日次で検知し、このリポジトリの設定への取り込み提案をIssueに投稿するワークフロー（`.github/workflows/claude-code-update-watch.yml`）です。

- 実行タイミング: 毎日JST 14:00（UTC 05:00）
- 仕組み: `anthropics/claude-code`のCHANGELOG.mdを取得し、前回処理済みバージョンとの差分をAIが要約して`claude-code-update`ラベル付きIssueを作成します
- 認証: リポジトリSecretの`CLAUDE_CODE_OAUTH_TOKEN`（`claude setup-token`で発行したOAuthトークン）を使用します

#### トークンの有効期限と再発行

`claude setup-token`で発行されるトークンの有効期限は1年間です。Maxサブスクリプションが有効である限り使えます。

トークンが失効するとワークフローの「Generate proposal」ステップが認証エラーで失敗します。`claude setup-token`で出力された文字列をコピーし、`gh secret set`でリポジトリSecretを更新します（「? Paste your secret:」と表示されたら貼り付けます）。

```bash
claude setup-token
gh secret set CLAUDE_CODE_OAUTH_TOKEN --repo manabuyasuda/dotfiles
```

### textlintとpre-commitフック

`.md`ファイルの文章品質はtextlintで検証します。検知は3層で行います。

1. ローカルの`git commit`時（lefthookによるpre-commit）
2. CI（`.github/workflows/textlint.yml`、PR時）
3. Claude Codeの編集時（PostToolUseフックで実行される`format.sh`）

#### 初回セットアップ

`npm ci`または`npm install`を実行すると、`package.json`の`prepare`スクリプトが`lefthook install`を呼び、`.git/hooks/pre-commit`が自動で配置されます。手動操作は不要です。

#### コミット時の挙動

- ステージ済みの`.md`ファイルに違反があると、コミットがexit code 1で止まります
- 違反がない場合、通常どおりコミットが完了します
- `lefthook.yml`の`glob: "*.md"`（basename match）で対象を絞っているため、`.md`以外のファイルだけをコミットするときtextlintは走りません

#### 緊急回避

CIや別レビューで品質を担保できる、あるいは違反検知に明らかな誤りがある場合に限り、`--no-verify`でフックをスキップできます。

```bash
git commit --no-verify -m "..."
```

CIの`textlint`ジョブは依然として走るため、`--no-verify`でローカルをすり抜けてもPRで再検知されます。常用しないでください。

#### 違反を自動修正したい場合

```bash
npm run lint:fix
```

修正できない違反（半角カナの混入など）は手動で直します。

## 管理対象外のツール

次はdotfilesでは管理していません。新しいマシンでは手動インストールが必要です。

- HHKB — [キーマップ変更ツール](https://happyhackingkb.com/jp/download/#keymap)を手動インストールします。設定はステップ2を参照してください
- OpenVPN Connect — [公式サイト](https://openvpn.net/client/)からインストールします。設定はNotionを参照してください
- Automator（FFmpeg/ImageMagick連携）— [設定手順](https://zenn.dev/chot/articles/8d2b0e6e0f7741)を参照してください。FFmpegとImageMagickはBrewfileからインストール済みです
- VS Code拡張機能 — GitHubアカウント同期で管理します

## 注意事項

- `.zprofile`のHomebrewパス（`/opt/homebrew`）はApple Silicon専用です。Intel Macでは異なります
- `.gitconfig`が参照する`.gitignore_global`と`.stCommitMsg`は管理対象外です
