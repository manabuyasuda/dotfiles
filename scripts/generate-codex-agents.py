#!/usr/bin/env python3
"""claude/agents/*/SUBAGENT.md から codex/agents/*.toml を生成する。"""

from __future__ import annotations

import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
AGENTS_SRC = ROOT / "claude" / "agents"
AGENTS_DST = ROOT / "codex" / "agents"

CODEX_TOOL_NOTE = """
## Codex 実行時の注意

- Claude Code 専用ツール（TaskCreate / TaskUpdate / TaskList 等）の記述は、Codex で利用可能なツールに読み替えて実行してください。
- パスが `~/.claude/` で始まる記述は、dotfiles の `setup.sh` 適用後にそのパスが存在する前提です（hooks・cache を共有）。
"""

CODEX_TRANSCRIPT_NOTE = """
## Codex での制約（transcript）

Codex では Claude Code の transcript JSONL（`~/.claude/projects/`）は利用できません。
transcript 取得ステップはスキップし、`git log`・Issue/PR・diff から「なぜ」を補完してください。
補完できない場合は、コミット計画の「ユーザーへ確認が必要な項目」に明記してください。
"""


def parse_frontmatter(content: str) -> tuple[dict[str, str], str]:
    if not content.startswith("---"):
        return {}, content
    parts = content.split("---", 2)
    if len(parts) < 3:
        return {}, content

    fm_text = parts[1]
    body = parts[2].lstrip("\n")
    meta: dict[str, str] = {}
    description_lines: list[str] = []
    in_description = False

    for line in fm_text.splitlines():
        if line.startswith("name:"):
            meta["name"] = line.split(":", 1)[1].strip()
            in_description = False
        elif line.startswith("description:"):
            rest = line.split(":", 1)[1].strip()
            if rest == ">":
                in_description = True
            elif rest:
                description_lines.append(rest)
                in_description = False
        elif re.match(r"^[A-Za-z0-9_]+:", line):
            in_description = False
        elif in_description and line.strip():
            description_lines.append(line.strip())

    if description_lines:
        meta["description"] = " ".join(description_lines)
    return meta, body


def expand_at_refs(body: str, agent_dir: pathlib.Path) -> str:
    lines: list[str] = []
    for line in body.splitlines():
        stripped = line.strip()
        match = re.match(r"^@(.+\.md)$", stripped)
        if match:
            ref = agent_dir / match.group(1)
            if ref.is_file():
                lines.append(f"\n--- {match.group(1)} ---\n")
                lines.append(ref.read_text(encoding="utf-8"))
                lines.append("")
            else:
                lines.append(line)
        else:
            lines.append(line)
    return "\n".join(lines)


def toml_literal_multiline(value: str) -> str:
    escaped = value.replace("\\", "\\\\").replace('"', '\\"')
    return f'"{escaped}"'


def toml_text_block(value: str) -> str:
    # TOML literal string: escape only """
    if '"""' in value:
        return toml_literal_multiline(value)
    return f'"""\n{value}\n"""'


def generate_agent(agent_dir: pathlib.Path) -> pathlib.Path | None:
    subagent = agent_dir / "SUBAGENT.md"
    if not subagent.is_file():
        return None

    content = subagent.read_text(encoding="utf-8")
    meta, body = parse_frontmatter(content)
    name = meta.get("name") or agent_dir.name
    description = meta.get("description") or ""

    instructions = expand_at_refs(body, agent_dir)
    if name == "commit-message-writer":
        instructions += CODEX_TRANSCRIPT_NOTE
    instructions += CODEX_TOOL_NOTE

    lines = [
        f"name = {toml_literal_multiline(name)}",
        f"description = {toml_literal_multiline(description)}",
        f"developer_instructions = {toml_text_block(instructions)}",
        "",
    ]

    AGENTS_DST.mkdir(parents=True, exist_ok=True)
    out = AGENTS_DST / f"{name}.toml"
    out.write_text("\n".join(lines), encoding="utf-8")
    return out


def main() -> int:
    if not AGENTS_SRC.is_dir():
        print(f"Error: {AGENTS_SRC} not found", file=sys.stderr)
        return 1

    generated: list[pathlib.Path] = []
    for agent_dir in sorted(AGENTS_SRC.iterdir()):
        if not agent_dir.is_dir():
            continue
        out = generate_agent(agent_dir)
        if out:
            generated.append(out)
            print(f"Generated {out.relative_to(ROOT)}")

    if not generated:
        print("No agents generated", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
