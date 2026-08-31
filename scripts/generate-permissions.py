#!/usr/bin/env python3
"""permissions/deny-rules.json から2つの生成物を作る。

  1. claude/settings.json の permissions.deny（Claude Code が直接読む）
  2. claude/hooks/pre-tool-use/deny-rules.txt（bash-guard.sh がシェル層で照合する）

Why: 拒否したい操作の一覧が claude/settings.json に手書きされていたため、
Codex CLI と Cursor CLI には1件も反映されていなかった。情報源を1つにし、
CLIごとの出力を生成物にすることで、片方だけ古くなる状態を作れなくする。

Why not: 出力先を claude/ の下に集約しない。deny は3つのCLIが共有する方針であり、
claude/ の下に置くと Claude Code 固有の設定に見えるため。

--check を付けると生成物との差分があるときに終了コード1で失敗する（CI・pre-commit 用）。
"""

from __future__ import annotations

import argparse
import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "permissions" / "deny-rules.json"
SETTINGS = ROOT / "claude" / "settings.json"
RULES_TXT = ROOT / "claude" / "hooks" / "pre-tool-use" / "deny-rules.txt"

# ホームディレクトリの書き方の揺れ（~ / $HOME / 絶対パス）をまとめて捕まえる。
# 絶対パスのユーザー名は環境ごとに違うため [^/[:space:]]+ で受ける（公開リポジトリに個人の値を書かない）。
HOME_ERE = r"(~|\$HOME|/Users/[^/[:space:]]+)/"

# POSIX ERE でメタ文字として働く文字だけをエスケープする。
# Why not: Python の re.escape は `-` のような無害な文字にも `\` を付ける。
# `\-` の意味は POSIX ERE では未定義で、grep の実装によって挙動が変わるため使わない。
_ERE_META = set(".[]()*+?^$|{}" + chr(92))


def ere_quote(text: str) -> str:
    return "".join(chr(92) + ch if ch in _ERE_META else ch for ch in text)


def path_to_ere(pattern: str) -> str:
    """パスのglobパターンを、コマンド文字列の中を探すERE（拡張正規表現）へ変換する。

    先頭の `**/` は「どこにあってもよい」の意味なので落とす（照合は行頭固定しない）。
    末尾の `*` も同様に落とす。途中の `*` だけ「区切りを跨がない任意文字列」にする。
    """
    body = pattern
    prefix = ""
    if body.startswith("**/"):
        body = body[3:]
    elif body.startswith("~/"):
        body = body[2:]
        prefix = HOME_ERE
    if body.endswith("*"):
        body = body[:-1]
    escaped = "".join(
        r"[^/[:space:]]*" if ch == "*" else ere_quote(ch) for ch in body
    )
    return prefix + escaped


def command_to_ere(tokens: list[str]) -> str:
    """コマンドのトークン列をEREへ変換する。

    フラグ（`-` で始まるトークン）の前には引数が入り得るため、
    `gh api /repos/... --method DELETE` のような実際の並びに届くよう間を許す。
    フラグ以外は隣接を要求し、無関係なコマンドに当たらないようにする。
    """
    parts = [r"(^|[|;&(]|[[:space:]])" + ere_quote(tokens[0])]
    for token in tokens[1:]:
        gap = r"([^|;&]*[[:space:]]+)?" if token.startswith("-") else r"[[:space:]]+"
        parts.append(gap + ere_quote(token))
    return "".join(parts)


def build_deny_list(rules: dict) -> list[str]:
    deny: list[str] = []
    for entry in rules["secretPaths"]:
        pattern = entry["pattern"]
        for tool in entry["claudeTools"]:
            deny.append(f"{tool}({pattern})")
        deny.append(f"Bash(cat {pattern})")
    for entry in rules["deniedCommands"]:
        deny.append(f"Bash({' '.join(entry['tokens'])}*)")
    return deny


def build_rules_txt(rules: dict) -> str:
    lines = [
        "# このファイルは scripts/generate-permissions.py が permissions/deny-rules.json から生成します。",
        "# 直接編集せず、permissions/deny-rules.json を編集してください。",
        "# 形式: <種別>\\t<ERE>\\t<説明>   種別 PATH=秘密ファイルのパス / CMD=拒否する命令",
    ]
    for entry in rules["secretPaths"]:
        lines.append(f"PATH\t{path_to_ere(entry['pattern'])}\t{entry['label']}")
    for entry in rules["deniedCommands"]:
        lines.append(f"CMD\t{command_to_ere(entry['tokens'])}\t{entry['label']}")
    return "\n".join(lines) + "\n"


def build_settings(deny: list[str]) -> str:
    settings = json.loads(SETTINGS.read_text(encoding="utf-8"))
    settings["permissions"]["deny"] = deny
    return json.dumps(settings, ensure_ascii=False, indent=2) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true", help="生成物とのずれがあれば終了コード1")
    args = parser.parse_args()

    if not SRC.is_file():
        print(f"Error: {SRC} not found", file=sys.stderr)
        return 1

    rules = json.loads(SRC.read_text(encoding="utf-8"))
    outputs = {
        SETTINGS: build_settings(build_deny_list(rules)),
        RULES_TXT: build_rules_txt(rules),
    }

    if args.check:
        stale = [
            path for path, content in outputs.items()
            if not path.is_file() or path.read_text(encoding="utf-8") != content
        ]
        if stale:
            for path in stale:
                print(f"Error: {path.relative_to(ROOT)} が permissions/deny-rules.json と同期していません", file=sys.stderr)
            print("FIX: bash scripts/generate-permissions.sh を実行して差分をコミットしてください", file=sys.stderr)
            return 1
        print("OK: 生成物は permissions/deny-rules.json と同期しています")
        return 0

    for path, content in outputs.items():
        path.write_text(content, encoding="utf-8")
        print(f"Generated {path.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
