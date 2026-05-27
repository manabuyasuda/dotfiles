---
title: フォーカスインジケーターを隠しません
impact: HIGH
tags: a11y, focus, keyboard
---

## フォーカスインジケーターを隠しません

キーボード操作中のユーザーは、ブラウザが描画するフォーカスインジケーターでフォーカス位置を把握しています。これを消すとフォーカス位置がわからなくなり、キーボードで操作できなくなります。

### 対象となるHTML要素

ブラウザが自動でフォーカスインジケーターを描画する要素です。

- `<a href>`
- `<button>`
- `<input>`
- `<textarea>`
- `<select>`
- `<summary>`
- `tabindex="0"`を付与した任意の要素
- interactiveなARIA role（`button`・`link`・`tab`・`menuitem`など）を付与した要素

### 確認するCSSセレクター

`outline`は複数のセレクターで決まります。片方が消えていても他方で復元されていれば問題ありません。以下のセレクターを組み合わせて確認します。

- `:focus`
- `:focus-visible`
- セレクター指定なし（例: `*`・要素セレクター・クラス単体）での`outline: none`

本ルールはフォーカスされる要素自身に描画されるインジケーターを対象とします。`:focus-within`は親要素のスタイルを変えるセレクターなので対象外です。マッチ要素自身がフォーカス可能な場合のみ`:focus`と同じ判定になります。

### 判定

| if | then |
|---|---|
| `:focus`またはセレクター指定なし（要素・クラス・`*`等）で`outline: none`を指定し、`:focus-visible`に`outline`の代替スタイルがある場合 | 許容します |
| `:focus`またはセレクター指定なし（要素・クラス・`*`等）で`outline: none`を指定し、`:focus-visible`の代替が`box-shadow`だけである場合 | 違反です |
| `:focus`またはセレクター指定なし（要素・クラス・`*`等）で`outline: none`を指定し、`:focus-visible`に代替スタイルがない場合 | 違反です |
| `:focus-visible`自体に`outline: none`を指定している場合 | 違反です |

`box-shadow`を代替に使うと、Windowsのハイコントラストモード（forced-colors）で表示されないためフォーカスインジケーターが消えます。代替スタイルは`outline`を指定します。

#### Incorrect

`outline: none`を指定しただけで代替がない例です。

```css
.tab {
  outline: none;
}
```

#### Correct

`:focus-visible`で代替スタイルを併記した例です。

```css
.tab {
  outline: none;
}
.tab:focus-visible {
  outline: 2px solid var(--color-focus);
  outline-offset: 2px;
}
```

実装後はキーボードのTabキーでフォーカス位置が視認できるか確認します。ハイコントラストモード（forced-colors）でも同様に視認できるか確認します。
