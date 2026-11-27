# /// script
# requires-python = ">=3.10,<3.15"
# dependencies = ["marko==2.2.5", "sudachipy==0.6.11", "sudachidict-core==20260723"]
# ///
"""Locate connective candidates in Markdown; line and column are one-based."""

import argparse
from bisect import bisect_right
from collections import defaultdict
import json
from pathlib import Path
import re
import sys

from marko import Markdown
from sudachipy import Dictionary

RULE_WORDS = """さらに しかも むしろ なぜなら というのは たとえば 例を挙げると しかし だが けれども つまり すなわち 言い換えると 要するに したがって だから なお ただし そして また まず 次に そのあと 加えて""".split()
CLAUSES = re.compile("けれども|けれど|ので|のに|ため|が")
RULE_START = re.compile(r"(?:\A|(?<=[。！？、，]))[ \t　\n]*")
SENTENCE_START = re.compile(r"(?:\A|(?<=[。！？]))[ \t　\n]*")
TSUTSUJI_FILE = Path(__file__).resolve().parents[1] / "resources/tsutsuji/connectives.jsonl"
PREDICATES = {"動詞", "形容詞", "助動詞"}
# In Tsutsuji 1.1u's connectID, these left classes include 10 (noun).
NOUN_LEFT = {"10", "b9", "c0", "c2", "c3", "e0", "e1", "eG", "g0", "g1", "gg"}


def prose_blocks(node, source):
    """Mask Markdown in place so parser and tokenizer offsets still refer to the file."""
    kind = type(node).__name__
    if kind == "Quote":
        return
    if kind in {"Paragraph", "TableCell"} and node.source_span:
        base, end = node.source_span
        raw = source[base:end]
        chars = ["\n" if c == "\n" else " " for c in raw]

        def copy_visible(child):
            if not child.source_span:
                return
            start, stop = child.source_span
            tag = type(child).__name__
            if tag in {"RawText", "Literal"}:
                chars[start - base : stop - base] = source[start:stop]
            elif tag in {"CodeSpan", "Image", "AutoLink", "Url"}:
                chars[start - base : stop - base] = "□" * (stop - start)
            elif tag != "InlineHTML" and isinstance(child.children, list):
                for part in child.children:
                    copy_visible(part)

        copy_visible(node)
        yield base, "".join(chars)
    elif isinstance(node.children, list):
        for child in node.children:
            yield from prose_blocks(child, source)


def load_tsutsuji():
    entries = defaultdict(lambda: defaultdict(set))
    try:
        for line in TSUTSUJI_FILE.read_text(encoding="utf-8").splitlines():
            row = json.loads(line)
            word = row["surface"]
            if not isinstance(word, str) or not word:
                raise ValueError("empty or invalid surface")
            kind = row["kind"]
            # Single-character clause markers also occur inside predicate sequences.
            if kind == "C" or (kind == "Q" and len(word) >= 2):
                entries[word[0]][word].add((kind, row["left"][:2]))
    except (OSError, ValueError, KeyError, IndexError, TypeError) as error:
        print(
            f"公開辞書を読み込めないため、個別ルールとSudachiで続行します ({TSUTSUJI_FILE}): {error}",
            file=sys.stderr,
        )
        return {}
    return entries


def case_and_binding_particles(tokens, first, stop):
    return (
        stop > first + 1
        and tokens[first].part_of_speech()[:2] == ("助詞", "格助詞")
        and all(tokens[i].part_of_speech()[:2] == ("助詞", "係助詞")
                for i in range(first + 1, stop))
    )


def tsutsuji_spans(chunk, offset, tokens, edges, sentence_starts, dictionary):
    for i, token in enumerate(tokens):
        start = token.begin()
        previous = tokens[i - 1].part_of_speech()[0] if i else None
        for word, variants in dictionary.get(chunk[start:start + 1], {}).items():
            end = start + len(word)
            if end not in edges or not chunk.startswith(word, start):
                continue
            if offset + start in sentence_starts and any(kind == "C" for kind, _ in variants):
                yield start, end
                continue
            if word == "ので" and chunk.startswith(("は", "あれば"), end):
                continue
            if previous in {"名詞", "代名詞"} and case_and_binding_particles(tokens, i, edges[end]):
                continue
            for kind, left in variants:
                if kind != "Q":
                    continue
                if ((previous in PREDICATES and left != "10")
                        or (previous in {"名詞", "代名詞"} and left in NOUN_LEFT)):
                    yield start, end
                    break


def candidates(text, tokenize, dictionary):
    matches = defaultdict(set)
    for start in RULE_START.finditer(text):
        pos = start.end()
        for word in RULE_WORDS:
            if text.startswith(word, pos):
                matches[pos, pos + len(word)].add("rule")
    starts = {start.end() for start in SENTENCE_START.finditer(text)}
    for sentence in re.finditer(r"[^。！？\n]+", text):
        # Sudachi caps the UTF-8 size of one input. Bound even unpunctuated paragraphs.
        for offset in range(sentence.start(), sentence.end(), 8000):
            chunk = text[offset : min(offset + 8000, sentence.end())]
            tokens = tokenize(chunk)
            for token in tokens:
                left = offset + token.begin()
                if left in starts and token.part_of_speech()[0] == "接続詞":
                    matches[left, offset + token.end()].add("sudachi")
            predicates = {
                t.end()
                for t in tokens
                if t.part_of_speech()[0] in PREDICATES
            }
            edges = {t.begin(): i for i, t in enumerate(tokens)}
            if dictionary:
                for start, end in tsutsuji_spans(chunk, offset, tokens, edges, starts, dictionary):
                    matches[offset + start, offset + end].add("tsutsuji")
            for match in CLAUSES.finditer(chunk):
                start, end = match.span()
                if start in predicates and end in edges:
                    if match[0] == "ので" and chunk.startswith(("は", "あれば"), end):
                        continue
                    matches[offset + start, offset + end].add("sudachi")

    # A longer expression beginning at the same position carries more context.
    previous_end = 0
    for (start, end), sources in sorted(
        matches.items(), key=lambda item: (item[0][0], -item[0][1])
    ):
        if start >= previous_end:
            yield start, end, sorted(sources)
            previous_end = end


def extract(source, line_range, public):
    dictionary = load_tsutsuji() if public else {}
    tokenize = Dictionary(dict="core").create().tokenize
    starts = [0] + [m.end() for m in re.finditer("\n", source)]
    root = Markdown(extensions=["gfm"]).parse(source)
    for base, text in prose_blocks(root, source):
        if not re.search("[ぁ-んァ-ヺ一-鿿]", text):
            continue
        for start, end, sources in candidates(text, tokenize, dictionary):
            left, right = base + start, base + end
            line = bisect_right(starts, left)
            if line_range and not line_range[0] <= line <= line_range[1]:
                continue
            yield {
                "line": line,
                "column": left - starts[line - 1] + 1,
                "surface": source[left:right],
                "sources": sources,
                "context": source[max(0, left - 55) : right + 55].strip(),
            }


def parse_range(arg):
    match = re.fullmatch(r"([1-9]\d*)-([1-9]\d*)", arg)
    if match:
        start, end = map(int, match.groups())
        if start <= end:
            return start, end
    raise argparse.ArgumentTypeError("expected inclusive line range START-END")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("file", type=Path)
    parser.add_argument("--lines", type=parse_range)
    parser.add_argument("--no-public-dictionary", action="store_true")
    args = parser.parse_args()
    hints = extract(
        args.file.read_text(encoding="utf-8"), args.lines, not args.no_public_dictionary
    )
    print(json.dumps(list(hints), ensure_ascii=False, separators=(",", ":")))
