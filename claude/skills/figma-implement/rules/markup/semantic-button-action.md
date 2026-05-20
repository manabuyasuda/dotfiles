---
title: 同ページの状態変更には`<button>`を使います
impact: HIGH
tags: semantic, button, action
---

## 同ページの状態変更には`<button>`を使います

URLが変わらない操作（モーダル開閉・フォーム送信・状態変更・タブ切り替えなど）でクリックされる要素です。a11yツリーから「ボタン」として認識され、キーボードのEnterで実行できます。

### 対象となる操作

クリックでURLが変わらない操作です。

- モーダル・ドロワー・ダイアログの開閉
- フォームの送信
- アプリの状態変更（チェックボックスの切り替え・並び順の変更など）
- タブの切り替え（URLハッシュを使わないSPA内タブ）

### 確認するHTML要素

`<button>`以外で状態変更を実装している可能性のあるパターンです。

- `<div onClick>`・`<span onClick>`で実装している
- `<a href="#">`・`<a href="javascript:void(0)">`・hrefなしの`<a>`で実装している
- `<form>`内の送信ボタンに`type`属性が指定されていない（暗黙的に`type="submit"`になる）

### 判定

| if | then |
|---|---|
| 同ページ操作を`<button>`で実装している場合 | 許容します |
| 同ページ操作を`<div>`・`<span>`・hrefなしの`<a>`・`<a href="#">`・`<a href="javascript:void(0)">`で実装している場合 | 違反です |
| `<form>`内のボタンで`type`属性が省略されている場合 | 送信ならそのまま（暗黙的に`type="submit"`）。それ以外は`type="button"`を明示します |

a11yツリーから操作可能要素として認識されない実装は、キーボード・スクリーンリーダーで使えなくなります。

#### Incorrect

`<div>`にハンドラーを付けただけの例です。a11yツリーから操作可能要素として認識されません。

```tsx
<div onClick={() => setOpen(true)}>開く</div>
```

#### Correct

`<button>`で実装した例です。

```tsx
<button type="button" onClick={() => setOpen(true)}>開く</button>
```

実装後はEnterキーで操作が実行されるか確認します。ブラウザのアクセシビリティパネルで「button」ロールとして認識されているかも確認します。
