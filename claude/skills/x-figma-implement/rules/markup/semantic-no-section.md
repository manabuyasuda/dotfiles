---
title: `<section>`は使いません
impact: HIGH
tags: semantic, landmark, structure
---

## `<section>`は使いません

`<section>`タグはユーザーエージェント（UA）の対応が不十分です。ランドマークやアウトラインといった想定の効果が得られません。ARIA仕様の`role="region"`としても、`aria-label`または`aria-labelledby`が必須です。指定しないと一般のスクリーンリーダーが認識しません。

### 対象となるHTML要素

`<section>`タグです。

### 確認するHTML要素

`<section>`を使っているコードです。

- セクション区切りに`<section>`を使っている
- 単なるレイアウト区切りで`<section>`を使っている
- `aria-label`なしで`<section>`を使っている

### 判定

| if | then |
|---|---|
| `<section>`を使っている場合 | 違反です |

代替手段は以下です。

- 単なるレイアウト区切りには`<div>`を使います
- 独立したコンテンツには`<article>`を使います
- ランドマークが必要な領域では`<main>`・`<aside>`・`<header>`・`<footer>`・`<nav>`を使い分けます
- 構造化が目的なら`<h1>`〜`<h6>`の見出し階層で表現します

#### Incorrect

レイアウト区切りに`<section>`を使った例です。

```tsx
<section className="features">
  <h2>機能一覧</h2>
  <ul>...</ul>
</section>
```

#### Correct

`<div>`に置き換えた例です。意味的な区切りは見出しが担います。

```tsx
<div className="features">
  <h2>機能一覧</h2>
  <ul>...</ul>
</div>
```

実装後はコードを検索して`<section>`が残っていないか確認します。
