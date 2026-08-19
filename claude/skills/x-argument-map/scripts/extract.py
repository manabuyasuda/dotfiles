# /// script
# requires-python = ">=3.10"
# dependencies = [
#     "sudachipy>=0.6.8,<0.7.0",
#     "sudachidict-core>=20240109",
# ]
# ///
"""extract.py — Markdown 文書から論の構造を読み解く材料を段落単位で抽出する。

判断はしない。段落ごとに、先頭文・断定文・根拠マーカー付き文・文頭接続詞・
留保表現を JSON で出力する。何を主張とみなし、根拠と対応しているかの判定は
スキル側のプロンプトが行う。exit code は入力エラー時のみ 1、それ以外は常に 0。

使い方:
    uv run extract.py draft.md            # JSON を標準出力へ
    uv run extract.py draft.md --outline  # 段落先頭文だけを行番号付きで並べる
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

from sudachipy import Dictionary, SplitMode

MARKERS_PATH = Path(__file__).with_name("markers.json")
FORMAL_NOUNS = {
    "こと", "もの", "とき", "ところ", "ため", "はず", "わけ", "つもり",
    "ほう", "うち", "まま", "せい", "おかげ", "点", "場合", "際", "上",
    "方", "件", "面",
    "時", "事", "所", "物", "為", "筈", "訳",
}
FUNCTIONAL_VERBS = {"する", "なる", "ある", "いる", "できる", "行う", "居る", "為る"}
REDUNDANT_WINDOW = 5
SENT_SPLIT = re.compile(r"(?<=[。！？!?])")
CODE_FENCE = re.compile(r"^(```|~~~)")
HEADING = re.compile(r"^#{1,6}\s")
LIST_ITEM = re.compile(r"^\s*([-*+]|\d+[.)])\s+")
TABLE_ROW = re.compile(r"^\s*\|")

_tok = Dictionary().create()


def load_markers() -> dict:
    return json.loads(MARKERS_PATH.read_text(encoding="utf-8"))


def paragraphs(md: str):
    """(start_line, kind, text) を返す。コードブロック・表は除外し、見出しは kind=heading。"""
    buf, start, in_code = [], None, False
    for i, raw in enumerate(md.splitlines(), 1):
        line = raw.rstrip()
        if CODE_FENCE.match(line):
            in_code = not in_code
            if buf:
                yield start, "body", " ".join(buf); buf, start = [], None
            continue
        if in_code or TABLE_ROW.match(line):
            continue
        if not line.strip():
            if buf:
                yield start, "body", " ".join(buf); buf, start = [], None
            continue
        if HEADING.match(line):
            if buf:
                yield start, "body", " ".join(buf); buf, start = [], None
            yield i, "heading", HEADING.sub("", line)
            continue
        if LIST_ITEM.match(line):
            if buf:
                yield start, "body", " ".join(buf); buf, start = [], None
            yield i, "list", LIST_ITEM.sub("", line)
            continue
        if not buf:
            start = i
        buf.append(line.strip())
    if buf:
        yield start, "body", " ".join(buf)


def sentences(text: str) -> list[str]:
    return [s.strip() for s in SENT_SPLIT.split(text) if s.strip()]


def strip_inline(text: str) -> str:
    text = re.sub(r"`[^`]*`", "コード", text)
    text = re.sub(r"\[([^\]]*)\]\([^)]*\)", r"\1", text)
    return re.sub(r"[*_]{1,2}([^*_]+)[*_]{1,2}", r"\1", text)


def content_nouns(sent: str) -> list[str]:
    """形式名詞・数詞・接尾辞を除いた名詞の表層形一覧。段2の話題語比較と段3問い3で使う。"""
    toks = _tok.tokenize(sent, SplitMode.C)
    out = []
    for t in toks:
        pos = t.part_of_speech()
        if pos[0] != "名詞":
            continue
        surface = t.surface()
        if surface in FORMAL_NOUNS:
            continue
        if pos[1] in ("非自立可能", "数詞", "接尾辞可能"):
            continue
        out.append(surface)
    return out


def content_words(sent: str) -> list[str]:
    """名詞・動詞・形容詞・形状詞のlemma一覧。redundant_with_prev の窓内比較に使う。

    名詞は content_nouns と同じ除外規則（形式名詞・数詞・接尾辞可能）を適用する。
    動詞は非自立可能と機能動詞（する・なる・ある・いる・できる・行う）を除外し、
    意味を担う実質語だけを残す。
    """
    toks = _tok.tokenize(sent, SplitMode.C)
    out = []
    for t in toks:
        pos = t.part_of_speech()
        surface = t.surface()
        lemma = t.dictionary_form()
        if pos[0] == "名詞":
            if surface in FORMAL_NOUNS:
                continue
            if pos[1] in ("非自立可能", "数詞", "接尾辞可能"):
                continue
            out.append(lemma)
        elif pos[0] == "動詞":
            if pos[1] == "非自立可能":
                continue
            if lemma in FUNCTIONAL_VERBS:
                continue
            out.append(lemma)
        elif pos[0] in ("形容詞", "形状詞"):
            out.append(lemma)
    return out


def sentence_end(sent: str) -> dict:
    """文末の品詞情報。名詞止め・断定・推量の判別材料。"""
    toks = _tok.tokenize(sent, SplitMode.C)
    core = [t for t in toks if not (t.part_of_speech()[0] == "補助記号")]
    if not core:
        return {"pos": None, "surface": None}
    last = core[-1]
    return {"pos": last.part_of_speech()[0], "surface": last.surface()}


def find_markers(sent: str, table: dict) -> list[dict]:
    candidates = []
    for kind, words in table.items():
        for w in words:
            pos = sent.find(w)
            if pos >= 0:
                candidates.append((pos, len(w), kind, w))
    candidates.sort(key=lambda c: (-c[1], c[0]))
    taken = []
    hits = []
    for pos, length, kind, w in candidates:
        end = pos + length
        if any(not (end <= s or pos >= e) for s, e in taken):
            continue
        taken.append((pos, end))
        hits.append({"kind": kind, "marker": w, "offset": pos})
    hits.sort(key=lambda h: h["offset"])
    return hits


def leading_conjunction(sent: str, table: dict) -> dict | None:
    head = re.sub(r"^[「（(]", "", sent)
    for kind, words in table.items():
        if kind.endswith("_particle"):
            continue
        for w in sorted(words, key=len, reverse=True):
            if head.startswith(w) and (len(head) == len(w) or head[len(w)] in "、,　 "):
                return {"kind": kind, "word": w}
    return None


def has_adversative_particle(sent: str, table: dict) -> str | None:
    """文中の逆接接続助詞（〜が、〜けれど、〜ものの等）を検出。最初にヒットした語を返す。"""
    words = table.get("adversative_particle", [])
    for w in sorted(words, key=len, reverse=True):
        if w in sent:
            return w
    return None


def analyze(md: str, markers: dict) -> dict:
    out = []
    heading_window: list[dict] = []
    for line, kind, text in paragraphs(md):
        if kind == "heading":
            heading_window = []
        raw_sents = sentences(text)
        sents = [strip_inline(s) for s in raw_sents]
        if not sents:
            continue
        entries = []
        for idx, s in enumerate(sents):
            end = sentence_end(s)
            hedges = [h for h in markers["hedge"] if h in s]
            evidence = find_markers(s, markers["evidence"])
            lc = leading_conjunction(s, markers["conjunction"])
            adv_particle = has_adversative_particle(s, markers["conjunction"])
            has_adversative = (lc is not None and lc["kind"] == "adversative") or adv_particle is not None
            cn = content_nouns(s)
            cw = content_words(s)
            redundant_with_prev = False
            if cw and end["pos"] is not None:
                for prev in reversed(heading_window[-REDUNDANT_WINDOW:]):
                    prev_cw = prev["content_words"]
                    if not prev_cw:
                        continue
                    if end["pos"] != prev["end_pos"]:
                        continue
                    if set(cw).issubset(set(prev_cw)):
                        redundant_with_prev = True
                        break
            entry = {
                "index": idx,
                "text": raw_sents[idx],
                "length": len(s),
                "end_pos": end["pos"],
                "end_surface": end["surface"],
                "assertive": not hedges and end["pos"] in ("動詞", "形容詞", "助動詞", "名詞", "形状詞"),
                "hedges": hedges,
                "evidence": evidence,
                "leading_conjunction": lc,
                "adversative_particle": adv_particle,
                "has_adversative": has_adversative,
                "content_nouns": cn,
                "content_words": cw,
                "redundant_with_prev": redundant_with_prev,
            }
            entries.append(entry)
            if kind != "heading":
                heading_window.append(entry)
        out.append({
            "line": line,
            "kind": kind,
            "first_sentence": raw_sents[0],
            "sentence_count": len(sents),
            "has_evidence_marker": any(e["evidence"] for e in entries),
            "hedge_count": sum(len(e["hedges"]) for e in entries),
            "sentences": entries,
        })
    return {"paragraphs": out}


def print_outline(result: dict) -> None:
    for p in result["paragraphs"]:
        tag = {"heading": "#", "list": "-", "body": " "}[p["kind"]]
        ev = "" if p["has_evidence_marker"] or p["kind"] != "body" else "  [根拠マーカーなし]"
        print(f"{p['line']:>4} {tag} {p['first_sentence']}{ev}")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("path")
    ap.add_argument("--outline", action="store_true", help="段落先頭文のみを表示")
    args = ap.parse_args()
    p = Path(args.path)
    if not p.is_file():
        print(f"error: not a file: {p}", file=sys.stderr)
        return 1
    result = analyze(p.read_text(encoding="utf-8"), load_markers())
    if args.outline:
        print_outline(result)
    else:
        json.dump(result, sys.stdout, ensure_ascii=False, indent=2)
        print()
    return 0


if __name__ == "__main__":
    sys.exit(main())
