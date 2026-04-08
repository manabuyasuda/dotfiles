# textlint

Markdown・テキストファイルの文章校正ツール。ルールセットやプラグインを組み合わせてプロジェクトに合わせた校正基準を定義できる。

## インストール

```bash
npm install --save-dev textlint
```

プリセット・ルールは用途に応じて追加する。

```bash
# 日本語向け基本セット
npm install --save-dev textlint-rule-preset-ja-technical-writing
npm install --save-dev textlint-rule-preset-ja-spacing

# 表記ゆれ統一
npm install --save-dev textlint-rule-prh
```

## 基本的な使い方

```bash
# チェックのみ
npx textlint '**/*.md'

# 自動修正
npx textlint --fix '**/*.md'

# 特定ファイルを対象
npx textlint docs/**/*.md
```

### package.json に登録する場合

グロブパターンはシングルクォートで囲む。クォートなしだと `/bin/sh` がシェル展開し、`**` が再帰展開されず対象ファイルが0件になる。

```json
{
  "scripts": {
    "lint": "textlint '**/*.md'",
    "lint:fix": "textlint --fix '**/*.md'"
  }
}
```

## 設定ファイル

`.textlintrc` に使用するルールを定義する。JSON・YAMLどちらの形式でも書ける。

```json
{
  "rules": {
    "preset-ja-technical-writing": {
      "sentence-length": { "max": 150 },
      "no-mix-dearu-desumasu": false,
      "ja-no-weak-phrase": false,
      "no-exclamation-question-mark": false,
      "max-kanji-continuous-len": { "max": 10 },
      "ja-no-mixed-period": false
    },
    "preset-ja-spacing": true,
    "prh": {
      "rulePaths": ["./dict/prh.yml"]
    }
  }
}
```

### lint 対象と除外設定

lint対象はグロブで指定し、除外は `.textlintignore` で管理する。`ja` 系プリセットは日本語パターンを検出する設計のため、英語ドキュメントには反応しない（エラーにならないが効果もない）。`prh` は辞書次第で英語にも適用される（ICS media辞書には英語のWeb技術用語が含まれる）。

```json
{
  "scripts": {
    "lint": "textlint 'docs/**/*.md' 'claude/**/*.md' README.md",
    "lint:fix": "textlint --fix 'docs/**/*.md' 'claude/**/*.md' README.md"
  }
}
```

`.textlintignore` はディレクトリを `/**` 形式で指定する（trailing `/` 形式は機能しない）。

```
# 例: 3rd party スキルを追加した場合
# claude/skills/vercel-*/**
```

## 主要プリセット

### preset-ja-technical-writing

技術文書向けの総合プリセット（21ルール）。以下を検出・修正する。

| ルール | 内容 |
|---|---|
| `sentence-length` | 文の長さ制限（デフォルト100文字） |
| `max-ten` | 読点の上限（デフォルト3個） |
| `no-dropping-the-ra` | ら抜き言葉 |
| `no-double-negative-ja` | 二重否定 |
| `no-mix-dearu-desumasu` | 敬体・常体の混在 |
| `no-doubled-joshi` | 助詞の重複 |
| `ja-no-redundant-expression` | 冗長表現 |
| `no-nfd` | Mac由来の破損文字 |
| `no-zero-width-spaces` | ゼロ幅スペース |
| `no-invalid-control-character` | 制御文字 |

デフォルト設定は制約が強すぎる場合もあるため、以下の調整を推奨する。

| 設定 | デフォルト | 推奨値 | 理由 |
|---|---|---|---|
| `sentence-length.max` | 100 | 150 | CLIオプションの説明など技術的な文章は100文字に収まらない |
| `no-mix-dearu-desumasu` | `true` | `false` | ドキュメントの種類によってスタイルが変わる場合があるため |
| `ja-no-weak-phrase` | `true` | `false` | 技術的な不確実性を表現する「かもしれない」等を許容するため |
| `no-exclamation-question-mark` | `true` | `false` | 記号を語として説明する場面（「！の後」等）があるため |
| `max-kanji-continuous-len.max` | 6 | 10 | 「自己署名証明書」など正当な技術用語が引っかかるため |
| `ja-no-mixed-period` | `true` | `false` | 表のセルや箇条書きは句点なしが自然なため |

### preset-ja-spacing

スペース周りのスタイル統一プリセット（8ルール）。

| ルール | 内容 | デフォルト |
|---|---|---|
| `ja-space-between-half-and-full-width` | 半角・全角文字間のスペース | 入れない |
| `ja-no-space-between-full-width` | 全角文字同士のスペース | 入れない |
| `ja-no-space-around-parentheses` | かっこ周りのスペース | 入れない |
| `ja-nakaguro-or-halfwidth-space-between-katakana` | カタカナ語間の区切り | 中黒か半角スペース |
| `ja-space-after-exclamation` | ！の後（文が続く場合） | 全角スペース |
| `ja-space-after-question` | ？の後（文が続く場合） | 全角スペース |
| `ja-space-around-code` | インラインコード周りのスペース | 無効（任意で有効化） |
| `ja-space-around-link` | リンク周りのスペース | 無効（任意で有効化） |

## textlint-rule-prh

YAML辞書ファイルで表記ゆれを検出・修正するルール。`--fix` で自動修正可能。

辞書ファイルの例（`dict/prh.yml`）。

```yaml
version: 1
rules:
  - expected: JavaScript
  - expected: TypeScript
  - expected: コンピューター
    pattern: コンピュータ
```

複数の辞書ファイルに分割して `imports` でまとめることができる。

```yaml
# dict/prh.yml
version: 1
imports:
  - ./prh_web_technology.yml
  - ./prh_cho_on.yml
  - ./prh_idiom.yml
```

### ICS media 辞書の参考

[textlint-rule-preset-icsmedia](https://github.com/ics-creative/textlint-rule-preset-icsmedia) の辞書（MITライセンス）がウェブ系コンテンツに適している。

| ファイル | 内容 |
|---|---|
| `prh_web_technology.yml` | Web技術用語の正式表記（Node.js, TypeScript, GitHubなど） |
| `prh_cho_on.yml` | 長音表記統一（コンピューター、ドライバーなど200語以上） |
| `prh_idiom.yml` | 外来語誤用・同音異義語（シミュレーション、アボカドなど200語以上） |
| `prh_duplicate.yml` | 重言（デビュー、後ろへバックなど） |
| `prh_open_close.yml` | 漢字の開き閉じ（後で→あとで、ある→あるなど） |
| `prh_redundancy.yml` | 冗長表現・二重敬語 |
| `prh_corporation.yml` | 企業名・ブランド名の正式表記 |

npmに公開されていないため、辞書ファイルをリポジトリにコピーして使う。

## その他のプリセット

### preset-japanese

汎用日本語文章向けの標準プリセット（12ルール）。`preset-ja-technical-writing` がほぼ内包しているため、両方入れる必要はない。

| ルール | 内容 |
|---|---|
| `sentence-length` | 文の最大長（デフォルト100文字） |
| `max-ten` | 読点の上限（デフォルト3個） |
| `no-doubled-joshi` | 助詞の重複 |
| `no-doubled-conjunctive-particle-ga` | 逆接の「が」の重複 |
| `no-doubled-conjunction` | 接続詞の重複 |
| `no-double-negative-ja` | 二重否定 |
| `no-dropping-the-ra` | ら抜き言葉 |
| `no-mix-dearu-desumasu` | 敬体・常体の混在 |
| `no-nfd` | Mac由来の破損文字 |
| `no-invalid-control-character` | 制御文字 |
| `no-zero-width-spaces` | ゼロ幅スペース |
| `no-kangxi-radicals` | 康煕部首（CJK異体文字） |

### preset-jtf-style

JTF日本語標準スタイルガイド（翻訳品質管理向け）に準拠したプリセット。句読点・数字・記号の表記を統一する。[ICS media](https://github.com/ics-creative/textlint-rule-preset-icsmedia) はこのプリセットを `preset-ja-technical-writing` の代わりに使用している。

よく使われるルール：

| ルール番号 | 内容 |
|---|---|
| 1.2.1 | 句点（。）と読点（、）を使う |
| 1.2.2 | ピリオド・カンマは使わない |
| 2.1.8 | 数字はアラビア数字 |
| 2.2.2 | 算用数字と漢数字の使い分け |
| 3.1.1 | 全角・半角文字間のスペース |
| 3.1.2 | 全角文字同士のスペース |
| 4.2.6 | ハイフンの扱い |
| 4.3.1 | 丸かっこ（）の扱い |
| 4.3.2 | 大かっこ［］の扱い |

### preset-ai-writing

AI生成テキストに見られる不自然なパターンを検出するプリセット（5ルール）。**textlint v15.1.0 以上が必要。**

```bash
npm install @textlint-ja/textlint-rule-preset-ai-writing
```

```json
{
  "rules": {
    "@textlint-ja/preset-ai-writing": true
  }
}
```

| ルール | 内容 |
|---|---|
| `no-ai-list-formatting` | 絵文字・太字プレフィックスなど機械的なリスト書式 |
| `no-ai-hype-expressions` | 「革新的」「業界標準を塗り替える」など過剰な誇大表現 |
| `no-ai-emphasis-patterns` | 過度な太字など機械的な強調構造 |
| `no-ai-colon-continuation` | 英語スタイルのコロン継続パターン |
| `ai-tech-writing-guideline` | 明確性・簡潔性・一貫性の技術文書ガイドライン |

## プリセット比較

| プリセット | ルール数 | 用途 | 備考 |
|---|---|---|---|
| `preset-ja-technical-writing` | 21 | 技術ドキュメント | もっとも厳格。設定でカスタマイズ推奨 |
| `preset-ja-spacing` | 8 | スペース統一 | `--fix` で自動修正可能 |
| `preset-japanese` | 12 | 汎用日本語 | `preset-ja-technical-writing` がほぼ内包 |
| `preset-jtf-style` | 多数 | 翻訳・スタイル準拠 | 一部ルールを選択して使う |
| `preset-ai-writing` | 5 | AI文章検出 | textlint v15.1.0+ 必須。パッケージ名 `@textlint-ja/textlint-rule-preset-ai-writing` |

## 参考リンク

- [GitHub - textlint](https://github.com/textlint/textlint)
- [GitHub - preset-ja-technical-writing](https://github.com/textlint-ja/textlint-rule-preset-ja-technical-writing)
- [GitHub - preset-ja-spacing](https://github.com/textlint-ja/textlint-rule-preset-ja-spacing)
- [GitHub - textlint-rule-prh](https://github.com/textlint-rule/textlint-rule-prh)
- [GitHub - preset-japanese](https://github.com/textlint-ja/textlint-rule-preset-japanese)
- [GitHub - preset-jtf-style](https://github.com/textlint-ja/textlint-rule-preset-JTF-style)
- [GitHub - preset-ai-writing](https://github.com/textlint-ja/textlint-rule-preset-ai-writing)
- [GitHub - textlint-rule-preset-icsmedia](https://github.com/ics-creative/textlint-rule-preset-icsmedia)
- [GitHub - textlint-rule-preset-smarthr](https://github.com/kufu/textlint-rule-preset-smarthr)
