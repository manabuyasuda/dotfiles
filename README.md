# dotfiles

macOS環境の設定ファイルを管理するリポジトリ。シンボリックリンク方式で、実ファイルをこのリポジトリ内に置き、ホームディレクトリからリンクを張る。

## ディレクトリ構造

```
dotfiles/
├── setup.sh              # セットアップスクリプト（シンボリックリンク作成）
├── macos.sh              # macOS設定の自動適用スクリプト
├── Brewfile              # Homebrewパッケージ一覧
├── zsh/
│   ├── .zshrc            # シェル設定（anyenv, direnv, PATH）
│   ├── .zprofile         # ログインシェル設定（Homebrew）
│   └── .zshenv           # 全シェル共通の環境変数
├── git/
│   └── .gitconfig        # Gitのグローバル設定
├── nodenv/
│   └── default-packages  # Node.jsインストール時に自動導入するnpmパッケージ
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

## セットアップ

### Macの初期化

調子が悪い場合や、新しいMacへ移行する前の既存Macの整理時に実施する。初期化後は「新しいマシンでのセットアップ」に従う。

参考: [Macを消去して出荷時の設定にリセットする - Apple公式](https://support.apple.com/ja-jp/102664)

#### 事前準備

1. 重要なデータをバックアップする（Time Machineまたはクラウド・外付けディスクへ手動コピー）
   - **Raycast**: Advanced → ExportでDropboxに設定ファイルをエクスポートする
2. Apple IDをサインアウトする（システム設定 → Apple ID → サインアウト）
   - Find My Macが有効な場合、サインアウトせずに初期化するとアクティベーションロックが残り、初期化後の再セットアップ時にApple IDとパスワードの入力が必要になる
   - 「すべてのコンテンツと設定を消去」を使う場合はウィザードがサインアウトまで誘導するため、事前の手動対応は不要
   - **売却・譲渡・貸与PCの返却時は必須**（サインアウトしないと次の所有者がMacを使えなくなる）
3. Bluetoothデバイスのペアリングを解除する
   - 自分で再使用する場合は不要。Mac側のペアリング情報は初期化で消えるため、初期化後にデバイス側から再ペアリングすればよい
   - **売却・譲渡・貸与PCの返却時は推奨**（デバイス側に情報が残り、相手が同じデバイスを使っている場合に誤接続のリスクがある）

#### 初期化

**macOS 12 Monterey以降（Apple SiliconまたはT2チップ搭載Mac）:**

システム設定 → 一般 → 転送またはリセット → すべてのコンテンツと設定を消去

**上記が使えない場合（復元モード）:**

- Apple Silicon: 電源ボタンを長押し → 「オプション」を選択
- Intel Mac: 再起動して `Command + R` を長押し

復元モード内で以下を実施する:

1. Disk Utility → Macintosh HDを選択 → 消去（APFS形式）
2. macOSを再インストール

### 新しいマシンでのセットアップ

#### 初期設定

1. macOSのセットアップウィザードでWi-Fiの接続とApple IDのサインインを行う
2. SafariでNotionにログインする（各種情報を参照するため）
3. [HHKBのMac用ドライバ](https://happyhackingkb.com/jp/download/macdownload.html)をインストールして設定する
   - キーボード設定アシスタントは表示されない場合もある。表示された場合は指示に従う
4. 外部ディスプレイとマウスを設定する（Macの詳細設定は後の手順で行うため、作業しやすくするための最小限の設定）
   - システム設定 → ディスプレイ → 配置で外部モニターを主ディスプレイに設定する
   - 解像度を変更する（27インチ4Kの場合は3008×1692）
   - マウスを接続し、システム設定 → マウスで速度を最大に設定する

#### 開発環境の構築

5. Command Line Toolsをインストールする

   ```bash
   xcode-select --install
   ```

6. [Homebrew](https://brew.sh/ja/)をインストールする

   ```bash
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

   # Apple Siliconの場合、インストール後に一時的にPATHを通す（.zprofileで永続化される）
   eval "$(/opt/homebrew/bin/brew shellenv)"
   ```

7. ディレクトリを作成してdotfilesをセットアップする

   ```bash
   # 作業ディレクトリを作成する
   # MY: 個人リポジトリ / PROJECT: 案件リポジトリ / Screenshot: スクリーンショット保存先
   mkdir -p ~/Documents/MY ~/Documents/PROJECT ~/Documents/Screenshot

   # dotfilesをクローンしてパッケージをインストールする
   git clone https://github.com/manabuyasuda/dotfiles ~/Documents/MY/dotfiles
   brew bundle install --file=~/Documents/MY/dotfiles/Brewfile --verbose
   cd ~/Documents/MY/dotfiles && ./setup.sh

   # 個人リポジトリをクローンする
   git clone https://github.com/manabuyasuda/manabuyasuda ~/Documents/MY/manabuyasuda
   ```

   `brew bundle install` が完了すると以下のように表示される:

   ```
   Homebrew Bundle complete! XX Brewfile dependencies now installed.
   ```

   アプリによってはパスワードを求められる場合がある。

   **AnkerWorkでエラーになる場合:** ロックファイルが残っていると競合で失敗することがある。ロックファイルを削除して再実行する:

   ```bash
   rm -f ~/Library/Caches/Homebrew/downloads/*AnkerWork*.incomplete
   brew bundle install --file=~/Documents/MY/dotfiles/Brewfile --verbose
   ```

   `setup.sh` は以下を実行する。何度実行しても安全（冪等）。
   - 既存ファイルを `~/.dotfiles_backup/` にバックアップしてからシンボリックリンクを作成
   - nodenv-default-packagesプラグインのインストールとdefault-packagesのリンク
   - `gh/extensions` に記載されたgh拡張機能のインストール

8. SSH鍵を設定してGitHubに登録する

   ```bash
   # 鍵を生成（-fは省略可能）
   ssh-keygen -t ed25519 -f ~/.ssh/<ファイル名>

   # macOSキーチェーンに登録（再起動後もパスフレーズ入力が不要になる）
   ssh-add --apple-use-keychain ~/.ssh/<ファイル名>

   # 公開鍵をクリップボードにコピーしてブラウザでGitHubに登録する
   pbcopy < ~/.ssh/<ファイル名>.pub
   open https://github.com/settings/ssh/new
   ```

   `~/.ssh/config` に設定を追記する:

   ```bash
   cat >> ~/.ssh/config << 'EOF'
   Host github.com
     AddKeysToAgent yes
     UseKeychain yes
     IdentityFile ~/.ssh/<ファイル名>
   EOF
   ```

   接続を確認する:

   ```bash
   ssh -T git@github.com
   ```

9. anyenvとnodenvをインストールする

   ```bash
   anyenv install --init
   anyenv install nodenv
   exec $SHELL -l
   ```

   最新LTSのバージョン番号を変数に格納して確認する（メジャーバージョンが偶数のものがLTS）:

   ```bash
   NODE_LTS=$(nodenv install --list | grep -E '^[0-9]+\.[0-9]+\.[0-9]+' | awk -F. 'int($1)%2==0' | tail -1)
   echo $NODE_LTS
   ```

   表示されたバージョンをインストールしてデフォルトに設定する:

   ```bash
   nodenv install $NODE_LTS
   nodenv global $NODE_LTS
   ```

   Node.jsのインストールにより `default-packages` に記載されたグローバルnpmパッケージが自動導入される（`@anthropic-ai/claude-code` を含む）。以降の手順はClaude Codeに委ねることができる。

   iTerm2（インストール済み）を開いて以下を実行する:

   ```bash
   code ~/Documents/MY/dotfiles
   claude
   ```

   Claude Codeが起動したら、以下のように依頼する:

   > README.mdの「新しいマシンでのセットアップ」を参照して、ステップ10以降を進めてください。

10. フォントをインストールする

    Noto Sans JPはBrewfileからインストール済み。Source Code Proはコマンドで手動インストールする。

    ```bash
    curl -LO https://github.com/adobe-fonts/source-code-pro/archive/release.zip
    unzip release.zip
    cp -a source-code-pro-release/TTF/* ~/Library/Fonts
    rm -rf release.zip source-code-pro-release
    ```

#### アプリの設定

11. 各アプリを設定する（Notionを参照）

    brewでインストールしたアプリはFinderから1つずつ起動して設定を進める。アクセシビリティやファイルアクセスなど、セキュリティに関する許可を求められるため、1つずつ確認しながら進めるとわかりやすい。

#### Macの設定

12. `macos.sh` を実行してシステム設定を一括適用する

    ```bash
    ~/Documents/MY/dotfiles/macos.sh
    ```

    以下は手動で設定する:

    **一般 → ログイン項目**（ログイン時に開く）
    - AutoRaise、BetterTouchTool、CotEditor、Cursor、DeepL、Dropbox、Google Chrome、iTerm、MeetingBar、Notion、PopClip、Raycast、Slack、Sourcetree

    **コントロールセンター（メニューバー）**
    - Spotlight：メニューバーに表示しない

    **デスクトップとDock**
    -

    **キーボード → キーボードショートカット**
    - Spotlight：すべてオフ（Raycastを使用するため）
    - 入力ソース（前の入力ソースを選択）：オフ
    - 「次のウィンドウを操作対象にする…」を選択、ショートカットの表示をクリックしてから設定したいショートカットを入力する

    **キーボード → 入力ソース → 日本語**
    - 入力モード：英字にチェックを入れる
    - タイプミスを修正：オフ
    - Windows風のキー操作：オン
    - 数字を全角入力：オフ

    **キーボード → 入力ソース → ABC** を削除する

    **iCloud → iCloudに保存済み → すべて見る**
    - 写真：クリックして「このMacを同期」のチェックを外して「Macから削除」

13. Macを再起動する

    ひととおりの設定が完了したら再起動する。システム設定の変更が反映され、アプリの許可ダイアログなどが表示される。

## 運用

### 設定ファイルを編集した場合

シンボリックリンク経由なので、`~/.zshrc` などを直接編集すればリポジトリ内のファイルが更新される。

```bash
cd ~/Documents/MY/dotfiles
git diff
git add -A && git commit -m "chore: 変更内容"
```

### Brewfile を更新する場合

```bash
brew bundle dump --file=~/Documents/MY/dotfiles/Brewfile --force
```

### Claude Code の設定を追加する場合

`claude/` ディレクトリ（`skills/`, `hooks/`）はディレクトリごとシンボリックリンクされているため、中にファイルを追加すると自動的にリポジトリに反映される。

`keybindings.json` など新しい個別ファイルを追加する場合は、`claude/` に作成してから `./setup.sh` を再実行する。

## 管理対象外のツール

以下はdotfilesでは管理していない。新しいマシンでは手動インストールが必要。

- **anyenv / nodenv** — anyenvはBrewfileからインストール済み。初期化はステップ9を参照
- **HHKB** — [Mac用ドライバ](https://happyhackingkb.com/jp/download/macdownload.html)を手動インストール。設定はステップ3を参照
- **OpenVPN Connect** — [公式サイト](https://openvpn.net/client/)からインストール。設定はNotionを参照
- **Automator（FFmpeg/ImageMagick連携）** — [設定手順](https://zenn.dev/chot/articles/8d2b0e6e0f7741)を参照。FFmpegとImageMagickはBrewfileからインストール済み
- **VS Code 拡張機能** — GitHubアカウント同期で管理

## 注意事項

- `.zprofile`のHomebrewパス（`/opt/homebrew`）はApple Silicon専用。Intel Macでは異なる
- `.gitconfig`が参照する`.gitignore_global`と`.stCommitMsg`は管理対象外
