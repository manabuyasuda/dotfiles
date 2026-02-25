# Firebase CLI (firebase-tools)

Firebaseプロジェクトの管理・デプロイを行う公式CLIツール。Hosting・Functions・Firestore・Emulator Suiteなどの操作をターミナルから行える。

## インストール

```bash
npm install -g firebase-tools
```

`nodenv/default-packages`で自動インストールされる。

## 基本的な使い方

```bash
# Google アカウントでログイン
firebase login

# カレントディレクトリを Firebase プロジェクトに初期化
firebase init

# 全サービスをデプロイ
firebase deploy

# Hosting のみデプロイ
firebase deploy --only hosting

# Functions のみデプロイ
firebase deploy --only functions
```

## 主要コマンド

### デプロイ・管理

| コマンド | 説明 |
|---|---|
| `firebase deploy` | 全サービスをデプロイする |
| `firebase deploy --only <target>` | 特定のサービスのみデプロイする |
| `firebase hosting:channel:deploy <id>` | プレビューチャンネルにデプロイする |
| `firebase hosting:channel:list` | プレビューチャンネルの一覧を表示する |

### エミュレーター（ローカル開発）

| コマンド | 説明 |
|---|---|
| `firebase emulators:start` | 全エミュレーターを起動する |
| `firebase emulators:start --only functions,firestore` | 指定したエミュレーターのみ起動する |
| `firebase emulators:export <dir>` | エミュレーターのデータをエクスポートする |
| `firebase emulators:start --import <dir>` | エクスポートしたデータを読み込んで起動する |

### Functions

| コマンド | 説明 |
|---|---|
| `firebase functions:log` | Functions のログを表示する |
| `firebase functions:shell` | Functions をローカルでインタラクティブに呼び出す |

### プロジェクト管理

| コマンド | 説明 |
|---|---|
| `firebase use <project-id>` | 使用するプロジェクトを切り替える |
| `firebase use --add` | プロジェクトエイリアスを追加する |
| `firebase projects:list` | プロジェクト一覧を表示する |

## ユースケース

### ローカルで Firebase を再現して開発する

```bash
firebase emulators:start
```

Functions・Firestore・Auth・Hostingなどをローカルでエミュレートする。本番環境に影響なくテストできる。

### プレビュー環境にデプロイしてレビューする

```bash
firebase hosting:channel:deploy pr-123
```

PRごとにプレビューURLを発行し、レビュアーが実際の動作を確認できる。

## 参考リンク

- [Firebase CLI リファレンス](https://firebase.google.com/docs/cli)
- [npm - firebase-tools](https://www.npmjs.com/package/firebase-tools)
