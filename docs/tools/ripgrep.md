# ripgrep

grep の高速な代替ツール。Rust製で、デフォルトで`.gitignore`を尊重し、バイナリファイルをスキップし、再帰検索を行う。`grep -r`と比較して数倍〜数十倍速いケースもあり、大規模リポジトリでの検索体験が劇的に変わる。

## インストール

```bash
brew install ripgrep
```

`Brewfile` で管理。コマンド名は `rg`。

## 基本的な使い方

```bash
# カレントディレクトリ以下を再帰検索
rg "useState"

# ファイルタイプを指定して検索
rg "useState" --type ts

# 大文字小文字を無視
rg -i "error"

# ファイル名のみ表示
rg -l "TODO"

# 正規表現で検索
rg "function\s+\w+"
```

## 主要オプション

### 検索

| オプション | 説明 |
| --- | --- |
| `-e PATTERN, --regexp=PATTERN` | 検索パターンを指定する（複数指定可） |
| `-f PATTERNFILE, --file=PATTERNFILE` | ファイルからパターンを読み込む |
| `-i, --ignore-case` | 大文字小文字を区別しない |
| `-s, --case-sensitive` | 大文字小文字を区別する |
| `-S, --smart-case` | パターンに大文字が含まれる場合のみ区別する（デフォルト） |
| `-w, --word-regexp` | 単語全体にマッチさせる |
| `-x, --line-regexp` | 行全体にマッチさせる |
| `-F, --fixed-strings` | パターンを正規表現ではなくリテラル文字列として扱う |
| `-P, --pcre2` | PCRE2正規表現エンジンを使用する（先読み・後読みなどが利用可能） |

### フィルタリング

| オプション | 説明 |
| --- | --- |
| `-t, --type=TYPE` | ファイルタイプで絞り込む（例: `ts`, `js`, `py`） |
| `-T, --type-not=TYPE` | 指定したファイルタイプを除外する |
| `-g, --glob=GLOB` | globパターンでファイルを絞り込む（`!`で除外） |
| `--hidden` | 隠しファイル・ディレクトリも検索対象にする |
| `-u, --unrestricted` | フィルターを段階的に緩和する（繰り返すほど制限が減る） |
| `-L, --follow` | シンボリックリンクをたどる |
| `-d, --max-depth=NUM` | ディレクトリの探索深度を制限する |
| `--max-filesize=NUM+SUFFIX` | 指定サイズを超えるファイルをスキップする（例: `1M`） |

### 出力制御

| オプション | 説明 |
| --- | --- |
| `-l, --files-with-matches` | マッチしたファイルのパスのみ表示する |
| `--files-without-match` | マッチしなかったファイルのパスを表示する |
| `-c, --count` | ファイルごとのマッチ行数を表示する |
| `--count-matches` | ファイルごとの個別マッチ数を表示する |
| `-o, --only-matching` | マッチした部分のみ表示する |
| `-n, --line-number` | 行番号を表示する（デフォルトで有効） |
| `-N, --no-line-number` | 行番号を非表示にする |
| `-H, --with-filename` | ファイル名を表示する |
| `--no-filename` | ファイル名を非表示にする |
| `-A NUM, --after-context=NUM` | マッチ行の後のN行を表示する |
| `-B NUM, --before-context=NUM` | マッチ行の前のN行を表示する |
| `-C NUM, --context=NUM` | マッチ行の前後N行を表示する |
| `-r, --replace=REPLACEMENT` | 出力上でマッチ部分を置換して表示する |
| `--json` | JSON Lines形式で出力する |
| `--stats` | 集計統計（ファイル数・マッチ数など）を表示する |
| `--heading` | ファイルごとにグループ化して表示する（ターミナルではデフォルト） |
| `-0, --null` | ファイル名の後にヌルバイトを付与する |
| `--sort=SORTBY` | 結果をソートする（`path`, `modified`, `accessed`, `created`） |
| `--sortr=SORTBY` | 結果を逆順でソートする |

### その他

| オプション | 説明 |
| --- | --- |
| `--files` | 検索対象となるファイル一覧を表示する（検索は実行しない） |
| `--type-list` | サポートされている全ファイルタイプを一覧表示する |
| `-j, --threads=NUM` | 使用するスレッド数を指定する |

## ユースケース

### ファイルタイプを指定して検索する

```bash
rg "useState" --type ts
```

`.ts`/`.tsx`ファイルのみを対象に高速検索する。`--type`で言語を指定すると、対応する拡張子を自動で判別する。

### TODO/FIXMEを一覧する

```bash
rg "TODO|FIXME|HACK" --type ts
```

プロジェクト内に残っている技術的負債のマーカーを洗い出す。

### 単語単位でマッチさせる

```bash
rg -w "error" --type ts
```

`error`という単語のみにマッチし、`errorMessage`や`handleError`などの部分一致を除外する。変数名やキーワードをピンポイントで検索したいときに有用。

### globパターンでファイルを絞り込む

```bash
# 特定のディレクトリ配下のみ検索する
rg "TODO" -g "src/components/**"

# テストファイルを除外して検索する
rg "TODO" -g "!*test*" -g "!*spec*"
```

`-g`でglobパターンを指定し、検索対象をファイルパスで柔軟に制御する。`!`を先頭に付けると除外パターンになる。

### 出力上でマッチ部分を置換する

```bash
rg "oldFunction" -r "newFunction" --type ts
```

ファイルの内容は変更せず、出力上でマッチ部分を置換して表示する。リファクタリング前の影響範囲の確認に便利。実際のファイル書き換えには`sed`等を組み合わせる。

### JSON出力で他ツールと連携する

```bash
rg "pattern" --json
```

JSON Lines形式で構造化されたデータとして取得し、`jq`などのツールやスクリプトに渡せる。

### 隠しファイルも含めて検索する

```bash
rg "API_KEY" --hidden
```

`.env`や`.config/`など、デフォルトでは無視される隠しファイル・ディレクトリも検索対象に含める。

### 結果をソートする

```bash
# ファイルパス順にソートする
rg "TODO" --sort path

# 最終更新日の新しい順にソートする
rg "TODO" --sortr modified
```

デフォルトではスレッド並列実行のため出力順は不定。`--sort`/`--sortr`で結果を整列させる（ソート有効時はシングルスレッドになる）。

### マッチ数を集計する

```bash
# ファイルごとのマッチ行数を表示する
rg -c "console.log" --type ts

# マッチの総数を含む統計情報を表示する
rg "console.log" --type ts --stats
```

`-c`でファイルごとのマッチ行数を確認し、`--stats`でプロジェクト全体の集計を得る。デバッグ用コードの残存状況などを定量的に把握できる。

## 参考リンク

- [GitHub - BurntSushi/ripgrep](https://github.com/BurntSushi/ripgrep)
