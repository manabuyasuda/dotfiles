# /// script
# requires-python = ">=3.12,<3.13"
# dependencies = [
#     "spacy>=3.7,<3.8",
#     "ja-ginza>=5.2,<6.0",
#     "click>=8.0",
# ]
# ///
"""sentence.py — Markdown 文書から文の構造を機械的に抽出する。

判断はしない。段落→文→トークンの3階層JSONを標準出力に返す。文ごとに6指標
（述語の主語有無、修飾語→係り先の文節距離、係り先候補数、連体修飾の入れ子
深さ、同じ助詞の連続、並列要素の揃い）を出す。何を悪文とみなすかはスキル側の
プロンプトが判断する。exit code は入力エラー時のみ 1、それ以外は常に 0。

段落分割は extract.py と揃える（コードブロック・表・見出し・箇条書きを扱う
規則を同じにする）。文分割も同じ正規表現を使う。分析はGiNZA (ja_ginza) で
行い、依存はPEP 723で固定する。

使い方:
    uv run sentence.py draft.md
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from collections import defaultdict
from pathlib import Path

import spacy
import ginza

SENT_SPLIT = re.compile(r"(?<=[。！？!?])")
CODE_FENCE = re.compile(r"^(```|~~~)")
HEADING = re.compile(r"^#{1,6}\s")
LIST_ITEM = re.compile(r"^\s*([-*+]|\d+[.)])\s+")
TABLE_ROW = re.compile(r"^\s*\|")

PREDICATE_POS = {"VERB", "ADJ", "AUX"}
NOUNY_POS = {"NOUN", "PROPN", "PRON", "NUM"}

_nlp = spacy.load("ja_ginza")


def paragraphs(md: str):
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


def bunsetsu_index_of(token, bspans) -> int:
    for bi, span in enumerate(bspans):
        if span.start <= token.i < span.end:
            return bi
    return -1


def case_particle(bspan) -> str | None:
    """文節末の格助詞・係助詞（が・を・に・へ・と・で・から・より・は・も等）を返す。"""
    for t in reversed(list(bspan)):
        if t.pos_ == "ADP":
            return t.orth_
        if t.pos_ in PREDICATE_POS | NOUNY_POS:
            break
    return None


def find_subject(pred_token, bunsetsu_of) -> dict | None:
    """述語の主語文節を返す。GiNZAのnsubj関係、なければ「が/は」で終わる修飾文節。"""
    for child in pred_token.children:
        if child.dep_ in ("nsubj", "nsubj:pass"):
            return {"text": child.sent.text[child.left_edge.idx - child.sent.start_char : child.right_edge.idx + len(child.right_edge.text) - child.sent.start_char], "token_i": child.i}
    pred_bi = bunsetsu_of.get(pred_token.i, -1)
    for bi, span in enumerate(pred_token.sent._.bunsetu_spans if hasattr(pred_token.sent._, "bunsetu_spans") else []):
        pass
    return None


def analyze_sentence(doc_sent) -> dict:
    sent_start = doc_sent.start
    try:
        bspans = list(ginza.bunsetu_spans(doc_sent))
    except Exception:
        bspans = []
    bunsetsu_of = {}
    for bi, span in enumerate(bspans):
        for t in span:
            bunsetsu_of[t.i] = bi

    tokens_out = []
    for t in doc_sent:
        tokens_out.append({
            "i": t.i - sent_start,
            "text": t.orth_,
            "lemma": t.lemma_,
            "pos": t.pos_,
            "tag": t.tag_,
            "dep": t.dep_,
            "head_i": t.head.i - sent_start,
            "bunsetsu": bunsetsu_of.get(t.i, -1),
        })

    predicates = []
    for t in doc_sent:
        if t.pos_ not in PREDICATE_POS:
            continue
        if t.pos_ == "AUX" and t.head.pos_ in PREDICATE_POS and t.head != t:
            continue
        subject = None
        subj_bi = None
        for child in t.children:
            if child.dep_ in ("nsubj", "nsubj:pass", "csubj"):
                subject = child.orth_
                subj_bi = bunsetsu_of.get(child.i, -1)
                break
        if subject is None:
            pred_bi = bunsetsu_of.get(t.i, -1)
            for bi in range(pred_bi - 1, -1, -1):
                span = bspans[bi]
                end_particle = case_particle(span)
                if end_particle in ("が", "は"):
                    subject = span.text
                    subj_bi = bi
                    break
        pred_bi = bunsetsu_of.get(t.i, -1)
        predicates.append({
            "text": t.orth_,
            "token_i": t.i - sent_start,
            "bunsetsu": pred_bi,
            "has_subject": subject is not None,
            "subject_text": subject,
            "subject_distance": (pred_bi - subj_bi) if subj_bi is not None and pred_bi >= 0 else None,
        })

    modifiers = []
    for t in doc_sent:
        if t.head == t:
            continue
        mod_bi = bunsetsu_of.get(t.i, -1)
        head_bi = bunsetsu_of.get(t.head.i, -1)
        if mod_bi < 0 or head_bi < 0 or mod_bi == head_bi:
            continue
        candidate_head_count = 0
        for bi in range(mod_bi + 1, len(bspans)):
            span = bspans[bi]
            head_tok = None
            for tk in span:
                if tk.pos_ in PREDICATE_POS | NOUNY_POS:
                    head_tok = tk
            if head_tok is None:
                continue
            if t.pos_ in ("ADJ", "DET") or t.dep_ in ("acl", "amod"):
                if head_tok.pos_ in NOUNY_POS:
                    candidate_head_count += 1
            elif t.pos_ == "ADV" or t.dep_ in ("advmod", "obl", "obj", "nsubj"):
                if head_tok.pos_ in PREDICATE_POS:
                    candidate_head_count += 1
            else:
                candidate_head_count += 1
        modifiers.append({
            "text": t.orth_,
            "token_i": t.i - sent_start,
            "bunsetsu": mod_bi,
            "head_bunsetsu": head_bi,
            "head_text": t.head.orth_,
            "bunsetsu_distance": head_bi - mod_bi,
            "candidate_head_count": candidate_head_count,
        })

    def acl_depth(tok, seen) -> int:
        if tok.i in seen:
            return 0
        seen.add(tok.i)
        d = 0
        for child in tok.children:
            if child.dep_ in ("acl", "amod"):
                d = max(d, 1 + acl_depth(child, seen))
        return d

    adnominal_max_depth = 0
    for t in doc_sent:
        if t.pos_ in NOUNY_POS:
            adnominal_max_depth = max(adnominal_max_depth, acl_depth(t, set()))

    consecutive = []
    run_particle, run_count, run_start = None, 0, -1
    prev_particle_bi = -1
    for bi, span in enumerate(bspans):
        p = case_particle(span)
        if p is None:
            continue
        if p == run_particle and bi == prev_particle_bi + 1:
            run_count += 1
        else:
            if run_count >= 2:
                consecutive.append({"particle": run_particle, "count": run_count, "start_bunsetsu": run_start})
            run_particle, run_count, run_start = p, 1, bi
        prev_particle_bi = bi
    if run_count >= 2:
        consecutive.append({"particle": run_particle, "count": run_count, "start_bunsetsu": run_start})

    parallel_groups = []
    conj_children = defaultdict(list)
    for t in doc_sent:
        if t.dep_ == "conj":
            conj_children[t.head.i].append(t)
    for head_i, items in conj_children.items():
        head_tok = doc_sent.doc[head_i]
        group = [head_tok] + items
        pos_set = {tk.pos_ for tk in group}
        case_set = set()
        for tk in group:
            tk_bi = bunsetsu_of.get(tk.i, -1)
            if tk_bi >= 0:
                cp = case_particle(bspans[tk_bi])
                case_set.add(cp)
        parallel_groups.append({
            "head_text": head_tok.orth_,
            "items": [tk.orth_ for tk in group],
            "pos_uniform": len(pos_set) == 1,
            "case_uniform": len(case_set) == 1,
            "cases": sorted([c for c in case_set if c is not None]),
        })

    return {
        "text": doc_sent.text,
        "bunsetsu_count": len(bspans),
        "predicates": predicates,
        "modifiers": modifiers,
        "adnominal_max_depth": adnominal_max_depth,
        "consecutive_same_particles": consecutive,
        "parallel_groups": parallel_groups,
        "tokens": tokens_out,
    }


def analyze(md: str) -> dict:
    out = []
    for line, kind, text in paragraphs(md):
        raw_sents = sentences(text)
        sents = [strip_inline(s) for s in raw_sents]
        if not sents:
            continue
        sent_entries = []
        for idx, s in enumerate(sents):
            doc = _nlp(s)
            doc_sent = next(iter(doc.sents), None)
            if doc_sent is None:
                continue
            entry = analyze_sentence(doc_sent)
            entry["index"] = idx
            entry["raw_text"] = raw_sents[idx]
            sent_entries.append(entry)
        out.append({
            "line": line,
            "kind": kind,
            "sentence_count": len(sent_entries),
            "sentences": sent_entries,
        })
    return {"paragraphs": out}


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("path")
    args = ap.parse_args()
    p = Path(args.path)
    if not p.is_file():
        print(f"error: not a file: {p}", file=sys.stderr)
        return 1
    result = analyze(p.read_text(encoding="utf-8"))
    json.dump(result, sys.stdout, ensure_ascii=False, indent=2)
    print()
    return 0


if __name__ == "__main__":
    sys.exit(main())
