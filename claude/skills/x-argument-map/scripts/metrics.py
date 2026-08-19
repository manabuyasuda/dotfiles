# /// script
# requires-python = ">=3.12,<3.13"
# dependencies = [
#     "sudachipy>=0.6.8,<0.7.0",
#     "sudachidict-core>=20240109",
#     "spacy>=3.7,<3.8",
#     "ja-ginza>=5.2,<6.0",
#     "click>=8.0",
# ]
# ///
"""metrics.py — Markdown 文書に対する目的関数（文と文章の量を必要最小限にする）の測定値をJSONで返す。

判断はしない。extract.py と sentence.py の解析結果から、書き直し前後で比較
できる5指標を集計する。何が「良い」かはスキル側のプロンプトとユーザーが判断
する。exit code は入力エラー時のみ 1、それ以外は常に 0。

出力する指標:
    char_count                     本文の文字数（コードブロック・表・見出し・箇条書きを除いた段落テキスト）
    sentence_count                 段落を分割した文の総数
    hedge_count                    留保表現の総出現数（同じ文に複数あれば個別に数える）
    modifier_distance_over_3       文節距離が3以上の修飾語の総数
    unsupported_assertion_count    留保なしで断定的に終わるが、根拠マーカーが同じ文にない文の数

使い方:
    uv run metrics.py draft.md
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import extract
import sentence


def compute(md: str) -> dict:
    markers = extract.load_markers()
    ex = extract.analyze(md, markers)
    sn = sentence.analyze(md)

    char_count = 0
    sentence_count = 0
    hedge_count = 0
    unsupported = 0
    for p in ex["paragraphs"]:
        for s in p["sentences"]:
            char_count += s["length"]
            sentence_count += 1
            hedge_count += len(s["hedges"])
            if s["assertive"] and not s["evidence"]:
                unsupported += 1

    modifier_over_3 = 0
    for p in sn["paragraphs"]:
        for s in p["sentences"]:
            for m in s["modifiers"]:
                if m["bunsetsu_distance"] >= 3:
                    modifier_over_3 += 1

    return {
        "char_count": char_count,
        "sentence_count": sentence_count,
        "hedge_count": hedge_count,
        "modifier_distance_over_3": modifier_over_3,
        "unsupported_assertion_count": unsupported,
    }


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("path")
    args = ap.parse_args()
    p = Path(args.path)
    if not p.is_file():
        print(f"error: not a file: {p}", file=sys.stderr)
        return 1
    result = compute(p.read_text(encoding="utf-8"))
    json.dump(result, sys.stdout, ensure_ascii=False, indent=2)
    print()
    return 0


if __name__ == "__main__":
    sys.exit(main())
