# Conventional Commitsのフォールバックルール

commitlintが設定されていないプロジェクトで使用する形式ルールです。commitlintが設定されている場合はこのファイルを読まず、commitlintの設定にしたがってください。

仕様の原典は[Conventional Commits v1.0.0](https://www.conventionalcommits.org/ja/v1.0.0/)です。

## Subject形式

`<type>(<scope>): <description>` の形式で書きます。

- scopeは常に付けます。判断による揺れを防ぐため例外はありません。値の決め方は`SKILL.md`のscopeのセクションを参照してください
- descriptionの末尾にピリオドを付けません
- 英語の場合は命令形・現在形で書きます
- typeの選び方は`type-selection.md`を参照してください

## 破壊的変更

以下のいずれかで示します。両方を併用してもかまいません。

- typeの後に`!`を付けます。例は`feat(api)!: drop legacy auth`です
- Footerに`BREAKING CHANGE: <内容>`を書きます

## Body

Bodyは必須です。変更が小さく見えても省略しません。内容の書き方は`SKILL.md`のBodyのセクションを参照してください。

## Footer形式

Bodyの後、1行空けてから記述します。

- `BREAKING CHANGE: <内容>` — 破壊的変更の詳細
- `Closes #123` / `Refs #456` — Issue / PRへの参照
