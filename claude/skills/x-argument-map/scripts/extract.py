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
from collections import deque
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
DEMONSTRATIVE_WINDOW = 3
SENT_SPLIT = re.compile(r"(?<=[。！？!?])")
HTML_COMMENT = re.compile(r"<!--.*?-->", re.DOTALL)
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


def predicate_count(sent: str) -> int:
    """文中の述語（動詞・形容詞・形状詞）のlemma数。手順粒度不整合の集計に使う。"""
    toks = _tok.tokenize(sent, SplitMode.C)
    n = 0
    for t in toks:
        pos = t.part_of_speech()
        if pos[0] == "動詞" and pos[1] != "非自立可能" and t.dictionary_form() not in FUNCTIONAL_VERBS:
            n += 1
        elif pos[0] in ("形容詞", "形状詞"):
            n += 1
    return n


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


def _first_content_noun(text: str) -> str | None:
    """text の先頭から最初に現れる実質名詞（形式名詞・数詞・接尾辞除外）の表層形。"""
    toks = _tok.tokenize(text, SplitMode.C)
    for t in toks:
        pos = t.part_of_speech()
        if pos[0] != "名詞":
            continue
        surface = t.surface()
        if surface in FORMAL_NOUNS:
            continue
        if pos[1] in ("非自立可能", "数詞", "接尾辞可能"):
            continue
        return surface
    return None


def find_demonstratives(sent: str, markers: dict) -> list[dict]:
    """指示語検出。裸の代名詞（これ・それ等）と連体詞（この・その等）を返す。

    連体詞は直後の実質名詞も抽出する（指示先の候補）。代名詞は常に指示先を
    要質問扱いにする。前後が文字境界（区切り記号・文頭文末）かで独立判定する。
    """
    hits = []
    boundary = set("、。「」（）()　 \t、,")
    for w in markers.get("demonstrative_pronoun", []):
        start = 0
        while True:
            pos = sent.find(w, start)
            if pos < 0:
                break
            end = pos + len(w)
            before_ok = pos == 0 or sent[pos - 1] in boundary
            after_ok = end >= len(sent) or sent[end] in boundary or sent[end] in "はがをにでとへも・、。"
            if before_ok and after_ok:
                hits.append({"surface": w, "kind": "pronoun", "offset": pos, "noun": None})
            start = pos + 1
    for w in markers.get("demonstrative_adnominal", []):
        start = 0
        while True:
            pos = sent.find(w, start)
            if pos < 0:
                break
            noun = _first_content_noun(sent[pos + len(w):])
            if noun:
                hits.append({"surface": w, "kind": "adnominal", "offset": pos, "noun": noun})
            start = pos + 1
    hits.sort(key=lambda h: h["offset"])
    return hits


def is_imperative(sent: str, markers: dict) -> bool:
    """文末が命令的（〜てください・〜ましょう・〜なさい）かを判定。"""
    tail = sent.rstrip("。！？!?」）) 　\t")
    for w in markers.get("imperative_ending", []):
        if tail.endswith(w):
            return True
    return False


def has_subject_marker(sent: str) -> bool:
    """文中に名詞+「は」「が」「こそ」の粗い主格文節があるかを判定する。

    仕様書での主体省略検出に使う。連体修飾内の「が」を除くため、直前トークンが
    実質名詞（形式名詞除外）である場合のみ真とする。誤検出は許容する（判断は
    スキル側）。
    """
    toks = list(_tok.tokenize(sent, SplitMode.C))
    for i, t in enumerate(toks):
        if t.part_of_speech()[0] != "助詞":
            continue
        if t.surface() not in ("は", "が", "こそ"):
            continue
        if i == 0:
            continue
        prev = toks[i - 1]
        prev_pos = prev.part_of_speech()
        if prev_pos[0] != "名詞":
            continue
        if prev.surface() in FORMAL_NOUNS:
            continue
        if prev_pos[1] in ("非自立可能",):
            continue
        return True
    return False


def find_conditionals(sent: str, markers: dict) -> list[str]:
    """条件表現（〜の場合は・〜のときは・〜なら等）のヒット一覧。"""
    hits = []
    for w in markers.get("conditional", []):
        if w in sent:
            hits.append(w)
    return hits


def has_definition(sent: str, markers: dict) -> bool:
    """定義パターン（〜とは・〜と呼ぶ・〜を意味する等）を含むか。"""
    for w in markers.get("definition_pattern", []):
        if w in sent:
            return True
    return False


def find_numbers_without_unit(sent: str, markers: dict) -> list[dict]:
    """数詞トークンで直後トークンが助数詞・接尾辞・単位記号・単位名詞でないものを返す。

    直後が補助記号（句読点・括弧・改行）または文末の場合はラベル・番号扱いとしてスキップする。
    「問い1」「段5」「L42」のような参照番号は数量表現ではなく、単位不足の検出対象外にする。
    """
    toks = list(_tok.tokenize(sent, SplitMode.C))
    unit_symbols = set("%％°㎏㎜㎝㎞")
    unit_nouns = set(markers.get("unit_noun", []))
    hits = []
    for i, t in enumerate(toks):
        pos = t.part_of_speech()
        if not (pos[0] == "名詞" and pos[1] == "数詞"):
            continue
        nxt = toks[i + 1] if i + 1 < len(toks) else None
        if nxt is None:
            continue
        npos = nxt.part_of_speech()
        nsurf = nxt.surface()
        if npos[0] == "補助記号":
            continue
        if npos[0] == "接尾辞":
            continue
        if npos[0] == "名詞" and npos[1] in ("助数詞可能", "接尾辞可能"):
            continue
        if len(nsurf) == 1 and nsurf in unit_symbols:
            continue
        if nsurf in unit_nouns:
            continue
        hits.append({"surface": t.surface(), "following": nsurf})
    return hits


def has_conditional_else(text: str, markers: dict) -> bool:
    """段落全文に対称の分岐（それ以外・そうでない場合等）を含むか。"""
    for w in markers.get("conditional_else", []):
        if w in text:
            return True
    return False


def _first_occurrence(current: list[str], seen: set[str]) -> list[str]:
    """文書全体で初出の名詞を返す。seenを破壊的に更新する。"""
    out = []
    for n in current:
        if n in seen:
            continue
        seen.add(n)
        out.append(n)
    return out


def _collect_list_groups(out: list[dict]) -> list[dict]:
    """連続する kind=="list" 段落を束ね、各項目の述語数と分散を返す。"""
    groups = []
    i = 0
    while i < len(out):
        if out[i]["kind"] != "list":
            i += 1
            continue
        j = i
        counts = []
        lines = []
        items = []
        while j < len(out) and out[j]["kind"] == "list":
            for s in out[j]["sentences"]:
                counts.append(s["predicate_count"])
                items.append(s["text"])
            lines.append(out[j]["line"])
            j += 1
        if len(counts) >= 2:
            mx, mn = max(counts), min(counts)
            dispersion = (mx / mn) if mn > 0 else (float("inf") if mx > 0 else 0.0)
            groups.append({
                "line_start": lines[0],
                "line_end": lines[-1],
                "item_count": len(counts),
                "predicate_counts": counts,
                "max": mx,
                "min": mn,
                "dispersion": None if dispersion == float("inf") else round(dispersion, 3),
                "dispersion_infinite": dispersion == float("inf"),
                "items": items,
            })
        i = j
    return groups


def analyze(md: str, markers: dict) -> dict:
    md = HTML_COMMENT.sub(lambda m: "\n" * m.group(0).count("\n"), md)
    out = []
    heading_window: list[dict] = []
    recent_content_nouns: deque[list[str]] = deque(maxlen=DEMONSTRATIVE_WINDOW)
    seen_nouns: set[str] = set()
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
            pc = predicate_count(s)
            demos = find_demonstratives(s, markers)
            recent_flat = [n for nouns in recent_content_nouns for n in nouns]
            for d in demos:
                if d["kind"] == "adnominal":
                    d["resolved"] = d["noun"] in recent_flat
                else:
                    d["resolved"] = False
            imperative = is_imperative(s, markers)
            subject_marker = has_subject_marker(s)
            conds = find_conditionals(s, markers)
            has_def = has_definition(s, markers)
            nums_wo_unit = find_numbers_without_unit(s, markers)
            first_occ = _first_occurrence(cn, seen_nouns)
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
                "predicate_count": pc,
                "redundant_with_prev": redundant_with_prev,
                "demonstratives": demos,
                "imperative": imperative,
                "has_subject_marker": subject_marker,
                "conditionals": conds,
                "has_definition": has_def,
                "numbers_without_unit": nums_wo_unit,
                "first_occurrence_nouns": first_occ,
            }
            entries.append(entry)
            if kind != "heading":
                heading_window.append(entry)
            recent_content_nouns.append(cn)
        out.append({
            "line": line,
            "kind": kind,
            "first_sentence": raw_sents[0],
            "sentence_count": len(sents),
            "has_evidence_marker": any(e["evidence"] for e in entries),
            "hedge_count": sum(len(e["hedges"]) for e in entries),
            "has_conditional_else": has_conditional_else(text, markers),
            "sentences": entries,
        })
    return {
        "paragraphs": out,
        "document_kind": _document_kind(out),
        "list_groups": _collect_list_groups(out),
    }


def _document_kind(paragraphs_out: list[dict]) -> dict:
    """全body段落を集計してmanual/essayを推定する。

    - assertive_ratio: body全文数のうち`assertive=true`の比率
    - hedge_density: body全文数のうち留保表現を含む文の比率
    - structural_ratio: 全段落のうちheading+listの比率

    assertive_ratio >= 0.9 かつ hedge_density < 0.1 かつ structural_ratio >= 0.4 で
    `manual`と判定する。evidenceマーカー（「ため」「から」等）は仕様書内の理由説明でも
    命中してしまい判定材料として信頼できないため使わない。論説文は「〜と考えます」
    「〜かもしれません」等でhedgeが散在するため、hedge_densityで区別できる。
    """
    all_sents = []
    for p in paragraphs_out:
        if p["kind"] == "body":
            all_sents.extend(p["sentences"])
    n = len(all_sents)
    assertive_ratio = sum(1 for s in all_sents if s["assertive"]) / n if n else 0.0
    hedge_density = sum(1 for s in all_sents if s["hedges"]) / n if n else 0.0
    total_p = len(paragraphs_out)
    structural_ratio = sum(1 for p in paragraphs_out if p["kind"] in ("heading", "list")) / total_p if total_p else 0.0
    is_manual = assertive_ratio >= 0.9 and hedge_density < 0.1 and structural_ratio >= 0.4
    return {
        "kind": "manual" if is_manual else "essay",
        "assertive_ratio": round(assertive_ratio, 3),
        "hedge_density": round(hedge_density, 3),
        "structural_ratio": round(structural_ratio, 3),
        "body_sentence_count": n,
    }


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
