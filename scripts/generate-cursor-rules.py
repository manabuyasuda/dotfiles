#!/usr/bin/env python3
"""claude/CLAUDE.md から cursor/rules/global-instructions.mdc を生成する。

Codex は setup.sh が claude/CLAUDE.md を .codex/AGENTS.md へシンボリックリンクするため
単一の情報源を保てる。Cursor は .mdc の frontmatter が必要でリンクにできないため、
frontmatter を付けたコピーをこのスクリプトで生成し、手書きによるドリフトを防ぐ。
"""

from __future__ import annotations

import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "claude" / "CLAUDE.md"
DST = ROOT / "cursor" / "rules" / "global-instructions.mdc"

FRONTMATTER = """---
description: グローバル指示（CLAUDE.md と同等。全プロジェクトに常時適用）
alwaysApply: true
---

<!-- このファイルは scripts/generate-cursor-rules.py が claude/CLAUDE.md から生成します。直接編集せず、claude/CLAUDE.md を編集してください。 -->
"""


def main() -> int:
    if not SRC.is_file():
        print(f"Error: {SRC} not found", file=sys.stderr)
        return 1

    body = SRC.read_text(encoding="utf-8").lstrip("\n")
    DST.parent.mkdir(parents=True, exist_ok=True)
    DST.write_text(f"{FRONTMATTER}\n{body}", encoding="utf-8")
    print(f"Generated {DST.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
