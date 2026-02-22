# dotfiles

macOS環境の設定ファイルを管理するリポジトリ。シンボリックリンク方式で、実ファイルをこのリポジトリ内に置き、ホームディレクトリからリンクを張る。

## 管理対象

| 領域 | ファイル | 説明 |
|------|---------|------|
| zsh | `.zshrc` | シェル設定（anyenv, direnv, PATH） |
| zsh | `.zprofile` | ログインシェル設定（Homebrew） |
| zsh | `.zshenv` | 全シェル共通の環境変数 |
| Git | `.gitconfig` | Git のグローバル設定 |
| Homebrew | `Brewfile` | インストールするパッケージ一覧 |
| nodenv | `default-packages` | Node.jsインストール時に自動導入するnpmパッケージ |
| gh | `extensions` | gh拡張機能の一覧 |
| Claude Code | `CLAUDE.md`, `settings.json`, `skills/`, `hooks/` | グローバル指示、hooks、カスタムスキル |

## ディレクトリ構造

```
dotfiles/
├── setup.sh          # セットアップスクリプト（シンボリックリンク作成）
├── macos.sh          # macOS設定の自動適用スクリプト
├── Brewfile          # Homebrew パッケージ一覧
├── zsh/
│   ├── .zshrc
│   ├── .zprofile
│   └── .zshenv
├── git/
│   └── .gitconfig
├── nodenv/
│   └── default-packages  # グローバルnpmパッケージ一覧
├── gh/
│   └── extensions        # gh拡張機能一覧
├── claude/
│   ├── CLAUDE.md
│   ├── settings.json
│   ├── skills/
│   └── hooks/
└── docs/
    └── tools/            # 開発ツールのドキュメント
```

## セットアップ

### Macの初期化

調子が悪い場合や、新しいMacへ移行する前の既存Macの整理時に実施する。初期化後は「新しいマシンでのセットアップ」に従う。

参考: [Macを消去して出荷時の設定にリセットする - Apple公式](https://support.apple.com/ja-jp/102664)

#### 事前準備

1. 重要なデータをバックアップする（Time Machineまたはクラウド・外付けディスクへ手動コピー）
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

1. Wi-Fiを接続する
2. SafariでNotionにログインする（各種情報を参照するため）
3. Apple IDでサインインする
4. [HHKBのMac用ドライバ](https://happyhackingkb.com/jp/download/macdownload.html)をインストールして設定する

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
   brew bundle --file=~/Documents/MY/dotfiles/Brewfile
   cd ~/Documents/MY/dotfiles && ./setup.sh

   # 個人リポジトリをクローンする
   gh repo clone manabuyasuda/manabuyasuda ~/Documents/MY/manabuyasuda
   ```

   `setup.sh` は以下を実行する。何度実行しても安全（冪等）。
   - 既存ファイルを `~/.dotfiles_backup/` にバックアップしてからシンボリックリンクを作成
   - nodenv-default-packagesプラグインのインストールとdefault-packagesのリンク
   - `gh/extensions` に記載されたgh拡張機能のインストール

8. SSH鍵を設定してGitHubに登録する

   ```bash
   # 鍵を生成（-fで任意のファイル名を指定する）
   ssh-keygen -t ed25519 -f ~/.ssh/<ファイル名>

   # macOSキーチェーンに登録（再起動後もパスフレーズ入力が不要になる）
   ssh-add --apple-use-keychain ~/.ssh/<ファイル名>

   # 公開鍵をクリップボードにコピーしてGitHubに登録する
   pbcopy < ~/.ssh/<ファイル名>.pub
   # → https://github.com/settings/ssh/new で貼り付けて登録
   ```

   `~/.ssh/config` に以下を追記する:

   ```
   Host github.com
     AddKeysToAgent yes
     UseKeychain yes
     IdentityFile ~/.ssh/<ファイル名>
   ```

   接続を確認する:

   ```bash
   ssh -T git@github.com
   ```

9. anyenv と nodenv をインストールする

   ```bash
   anyenv install --init
   anyenv install nodenv
   exec $SHELL -l

   # インストール可能なバージョンを確認して最新LTSを導入
   nodenv install --list
   nodenv install <バージョン>
   nodenv global <バージョン>
   ```

   Node.jsのインストールにより `default-packages` に記載されたグローバルnpmパッケージが自動導入される（`@anthropic-ai/claude-code` を含む）。以降の手順はClaude Codeに委ねることができる。

   ```bash
   # CursorでdotfilesリポジトリをREADMEごと開き、Claude Codeを起動する
   cursor ~/Documents/MY/dotfiles
   claude
   ```

   Claude Codeが起動したら、以下のように依頼する:

   > README.mdの「新しいマシンでのセットアップ」を参照して、ステップ10以降を進めてください。

#### アプリの設定

10. 各アプリを設定する（Notionを参照）

#### Macの設定

11. `macos.sh` を実行してシステム設定を一括適用する

   ```bash
   ~/Documents/MY/dotfiles/macos.sh
   ```

   以下は手動で設定する:

   **一般 → ログイン項目**（ログイン時に開く）
   - AutoRaise、BetterTouchTool、CotEditor、DeepL、Dropbox、Google Chrome、iTerm、MeetingBar、Notion、PopClip、Raycast、Slack、Sourcetree

   **コントロールセンター（メニューバー）**
   - Bluetooth：メニューバーに表示
   - 画面ミラーリング：メニューバーに表示しない
   - Spotlight：メニューバーに表示しない

   **キーボード → キーボードショートカット**
   - LaunchpadとDock → Dockを自動的に表示/非表示のオン/オフ：オフ
   - Spotlight：すべてオフ（Raycastを使用するため）
   - Mission Control：すべてオフ
   - 入力ソース（前の入力ソースを選択）：オフ
   - 音声入力：オフ
   - サービス：すべてオフ
   - [同じアプリケーションの違うウィンドウを選択するショートカット](https://zenn.dev/manabuyasuda/articles/86e0247ea8c712#同じアプリケーションの違うウィンドウを選択するショートカット)を設定する

   **キーボード → 入力ソース → 日本語**
   - 入力モード：英字にチェックを入れる
   - Windows風のキー操作：オン
   - 数字を全角入力：オフ
   - タイプミスを修正：オフ
   - 書類ごとに入力ソースを自動的に切り替える：オン

   **キーボード → 入力ソース → ABC** を削除する

   **Apple ID → iCloud**
   - 写真：オフ

   **インターネットアカウント**
   - 会社アカウントのメールとカレンダーを追加する（認証が必要）

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

- **anyenv / nodenv** — `anyenv install --init` → `anyenv install nodenv`
- **OpenVPN Connect** — [公式サイト](https://openvpn.net/client/)からインストール。設定はNotionを参照
- **Automator（FFmpeg/ImageMagick連携）** — [設定手順](https://zenn.dev/chot/articles/8d2b0e6e0f7741)を参照。FFmpegとImageMagickはBrewfileからインストール済み
- **VS Code 拡張機能** — GitHubアカウント同期で管理

## 注意事項

- `.zprofile`のHomebrewパス(`/opt/homebrew`)はApple Silicon専用。Intel Macでは異なる
- `.gitconfig`が参照する`.gitignore_global`と`.stCommitMsg`は管理対象外
