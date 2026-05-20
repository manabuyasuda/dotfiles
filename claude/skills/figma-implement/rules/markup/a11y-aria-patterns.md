---
title: 動的コンポーネントはWAI-ARIA APGに準拠した属性を指定します
impact: HIGH
tags: a11y, aria, patterns
---

## 動的コンポーネントはWAI-ARIA APGに準拠した属性を指定します

タブ・アコーディオン・モーダル・メニューなど、動的コンポーネントは属性の組み合わせで状態と関係性をスクリーンリーダーに伝えます。WAI-ARIA Authoring Practices Guide（APG）は実装可能なパターンとして属性・キーボード操作・状態遷移を示しています。

### 参照ドキュメント

- [WAI-ARIA Authoring Practices Guide (APG)](https://www.w3.org/WAI/ARIA/apg/patterns/)
- [Accessible Rich Internet Applications (WAI-ARIA) 1.2](https://www.w3.org/TR/2023/REC-wai-aria-1.2-20230606/)

### 対象となるコンポーネント

APGにパターン定義のある動的コンポーネントです。

- タブ・タブリスト（tabs）
- アコーディオン（accordion / disclosure）
- モーダル・ダイアログ（dialog / alertdialog）
- ドロップダウンメニュー（menu / menubar）
- コンボボックス（combobox）
- ツリービュー（tree）
- アラート・ステータス（alert / status）
- カルーセル（carousel）

### 確認する属性

各パターンに必須または推奨されている属性です。実装時はAPGの該当ページを開いて、属性が揃っているか確認します。

| 種別 | 属性の例 |
|---|---|
| ロール | `role="tab"`・`role="tabpanel"`・`role="dialog"`など |
| 状態 | `aria-expanded`・`aria-selected`・`aria-checked`・`aria-current`など |
| 関係 | `aria-controls`・`aria-labelledby`・`aria-describedby`・`aria-owns`など |
| 表示制御 | `aria-hidden`・`aria-modal`・`aria-live`など |

### 判定

| if | then |
|---|---|
| APGに定義されたパターンで役割・状態・関係の属性が揃っている場合 | 許容します |
| `role`は付与しているのに状態属性（`aria-expanded`等）が欠けている場合 | 違反です |
| `role`は付与しているのに関係属性（`aria-controls`等）が欠けている場合 | 違反です |
| APGに定義のあるパターンを`<div>`と独自クラスで実装している場合 | 違反です |
| キーボード操作（矢印キー・Esc・Enter等）が実装されていない場合 | 違反です（APGに定義あり） |

#### Incorrect

タブを`role="tab"`だけで実装し、選択状態と関連性が欠けている例です。

```tsx
<div>
  <div role="tab" onClick={() => setActive(0)}>タブ1</div>
  <div role="tab" onClick={() => setActive(1)}>タブ2</div>
</div>
<div>{content[active]}</div>
```

#### Correct

APGのTabs patternに沿った例です。`role="tablist"`・`aria-selected`・`aria-controls`・キーボード操作を含みます。

```tsx
<div role="tablist" aria-label="設定">
  <button
    role="tab"
    aria-selected={active === 0}
    aria-controls="panel-0"
    id="tab-0"
    tabIndex={active === 0 ? 0 : -1}
    onClick={() => setActive(0)}
    onKeyDown={handleArrowKeys}
  >
    タブ1
  </button>
  <button
    role="tab"
    aria-selected={active === 1}
    aria-controls="panel-1"
    id="tab-1"
    tabIndex={active === 1 ? 0 : -1}
    onClick={() => setActive(1)}
    onKeyDown={handleArrowKeys}
  >
    タブ2
  </button>
</div>
<div role="tabpanel" id="panel-0" aria-labelledby="tab-0" hidden={active !== 0}>
  {content[0]}
</div>
<div role="tabpanel" id="panel-1" aria-labelledby="tab-1" hidden={active !== 1}>
  {content[1]}
</div>
```

実装後はスクリーンリーダー（macOS: VoiceOver、Windows: NVDA）でタブ移動・状態変更・パネル切り替えがアナウンスされるか確認します。キーボード単独で全操作が完結することも確認します。
