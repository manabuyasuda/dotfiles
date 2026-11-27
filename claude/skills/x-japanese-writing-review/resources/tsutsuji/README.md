# 日本語機能表現辞書「つつじ」の接続表現

`connectives.jsonl` は、松吉俊・佐藤理史による日本語機能表現辞書「つつじ」1.1uから作成しました。© 2008 Suguru Matsuyoshi and Satoshi Sato. 元の辞書とこの抽出データはCC BY-SA 4.0で提供します。[公式配布ページ](https://sites.google.com/edu.teu.ac.jp/cl-lab/研究/言語資源/日本語機能表現辞書つつじ)・[ライセンス](https://creativecommons.org/licenses/by-sa/4.0/)

元の `L9.list` から接続詞型（C）と接続助詞型（Q）の439項目を選び、表記・ID・型・意味分類・左接続・右接続の6項目をJSON Linesに変換しました。異なる用法で同じ表記が使われるため、375の異なる表記に対して439行あります。

## 辞書を更新するとき

保守担当者は公式配布ページから `tsutsuji-1.1u.zip` を取得し、スキルのディレクトリで次を実行します。生成器は元ZIPのSHA-256を照合します。利用者は同梱済みのデータを使えます。

```sh
python3 scripts/build-tsutsuji.py /path/to/tsutsuji-1.1u.zip --output resources/tsutsuji/connectives.jsonl
```

別の版を採用するときは、配布元・ライセンス・項目の形式を確認して生成器の版とSHA-256を更新し、再生成した辞書の差分を確認します。抽出器は左接続の分類の一部をSudachiの品詞に対応づけているため、配布物の `connectID` が変わった場合はこの対応も確認します。[生成器と1.1uのSHA-256](../../scripts/build-tsutsuji.py)・[抽出器](../../scripts/connective-hints.py)
