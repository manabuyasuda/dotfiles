"""Select connective entries from the official Tsutsuji 1.1u ZIP as JSON lines."""

import argparse
import csv
import hashlib
import io
import json
from pathlib import Path
import sys
import tempfile
from zipfile import ZipFile

ARCHIVE_SHA256 = "38ecf8f9d147edd7c167d31fa0a8c11648a7896fbdb1d66544aacd98c4697270"


def select(archive):
    content = archive.read_bytes()
    if hashlib.sha256(content).hexdigest() != ARCHIVE_SHA256:
        raise ValueError("ZIP does not match the pinned Tsutsuji 1.1u SHA-256")
    with ZipFile(io.BytesIO(content)) as package:
        with package.open("tsutsuji-1.1u/L9.list") as entry:
            for row in csv.reader(io.TextIOWrapper(entry, encoding="utf-8", newline="")):
                surface, entry_id = row[:2]
                # The L3 code follows the four-character L2 ID (schema.xsd).
                kind = entry_id[4]
                if kind in {"C", "Q"}:
                    yield {
                        "surface": surface,
                        "id": entry_id,
                        "kind": kind,
                        "meaning": row[-1],
                        "left": row[6],
                        "right": row[7],
                    }


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", type=Path, help="path to tsutsuji-1.1u.zip")
    parser.add_argument("--output", type=Path, help="JSONL file (default: stdout)")
    args = parser.parse_args()
    try:
        lines = (json.dumps(item, ensure_ascii=False) + "\n" for item in select(args.archive))
        data = "".join(lines).encode("utf-8")
        if args.output is None:
            sys.stdout.buffer.write(data)
        else:
            with tempfile.TemporaryDirectory(dir=args.output.parent) as directory:
                temporary = Path(directory) / "connectives.jsonl"
                temporary.write_bytes(data)
                temporary.replace(args.output)
    except (OSError, ValueError) as error:
        parser.exit(1, f"{error}\n")
