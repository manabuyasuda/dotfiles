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
HOME_ERE = r"(~|\$HOME|\$\{HOME\}|/Users/[^/[:space:]]+)/"

# パス構成要素の先頭であることを要求する。
# Why: `**/.env*` は「構成要素が .env で始まる」の意味で、`process.env` は元から対象外。
# 境界を要求しないと、tool層（Read(**/.env*)）が止めないものをhook層だけが止め、
# claude/settings.json を読んでも実際に何が止まるか分からなくなる。
BOUNDARY = r"(^|[^[:alnum:]_.-])"

# POSIX ERE でメタ文字として働く文字だけをエスケープする。
# Why not: Python の re.escape は `-` のような無害な文字にも `\` を付ける。
# `\-` の意味は POSIX ERE では未定義で、grep の実装によって挙動が変わるため使わない。
_ERE_META = set(".[]()*+?^$|{}" + chr(92))


def ere_quote(text: str) -> str:
    return "".join(chr(92) + ch if ch in _ERE_META else ch for ch in text)


def path_to_ere(pattern: str, *, strict: bool = True) -> str:
    """パスのglobパターンを、コマンド文字列の中を探すERE（拡張正規表現）へ変換する。

    先頭の `**/` は「どこにあってもよい」の意味なので落とす（照合は行頭固定しない）。
    末尾の `*` も同様に落とす。途中の `*` だけ「区切りを跨がない任意文字列」にする。

    strict=True はglobが表す範囲に忠実な照合を作る（deny 用）。
    strict=False はホームの指定を外した広い照合を作る（ask 用）。
    どちらも直前が識別子の文字でないことを要求する。
    """
    body = pattern
    prefix = ""
    if body.startswith("**/"):
        body = body[3:]
        prefix = BOUNDARY if strict else ""
    elif body.startswith("~/"):
        body = body[2:]
        prefix = HOME_ERE if strict else BOUNDARY
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

    フラグの直後の値は、空白・`=`・連結のどれでも書ける。
    `--method DELETE` / `--method=DELETE` / `-XDELETE` はすべて同じ命令なので、
    区切りを空白に限定すると後ろ2つが素通りする。
    """
    parts = [r"(^|[|;&(]|[[:space:]])" + ere_quote(tokens[0])]
    prev = tokens[0]
    for token in tokens[1:]:
        if token.startswith("-"):
            gap = r"([^|;&]*[[:space:]]+)?"
        elif prev.startswith("-"):
            gap = r"[[:space:]]*=?[[:space:]]*"
        else:
            gap = r"[[:space:]]+"
        parts.append(gap + ere_quote(token))
        prev = token
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
        "# 形式: <種別>\\t<ERE>\\t<説明>",
        "# 種別 PATH=秘密ファイルのパス（deny） / CMD=拒否する命令（deny） / PATHASK=範囲外の一致（ask）",
        "# 上から順に照合し、最初に一致した行で判定する。denyの行を先に並べる。",
    ]
    # PATHASK は「globの範囲外だが秘密ファイルの名前を含む」命令を拾う。
    # Why: 検知を落とさずに、確実に危険なもの（deny）と判断が要るもの（ask）を分ける。
    # ユーザーは ask で内容を確認し、自分で実行するか別の方法を指示できる。
    ask_lines: list[str] = []
    for entry in rules["secretPaths"]:
        strict = path_to_ere(entry["pattern"], strict=True)
        loose = path_to_ere(entry["pattern"], strict=False)
        lines.append(f"PATH\t{strict}\t{entry['label']}")
        if loose != strict:
            ask_lines.append(f"PATHASK\t{loose}\t{entry['label']}")
    for entry in rules["deniedCommands"]:
        lines.append(f"CMD\t{command_to_ere(entry['tokens'])}\t{entry['label']}")
    return "\n".join(lines + ask_lines) + "\n"


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
            # 「同期していません」だけだと、どちらを直せばよいか読み手が判断できない。
            # 生成物は必ず上書きされる側なので、生成物を直すのだと分かる文言にする。
            for path in stale:
                rel = path.relative_to(ROOT)
                if not path.is_file():
                    print(f"Error: {rel} がありません（permissions/deny-rules.json から生成される側のファイルです）", file=sys.stderr)
                else:
                    print(f"Error: {rel} の内容が古いままです。permissions/deny-rules.json から生成し直す必要があります", file=sys.stderr)
            print("FIX: bash scripts/generate-permissions.sh を実行し、生成物を git add で同じコミットへ含めてください", file=sys.stderr)
            print("     permissions/deny-rules.json 以外を直接編集した場合、その編集は上書きされます", file=sys.stderr)
            return 1
        print("OK: 生成物は permissions/deny-rules.json と同期しています")
        return 0

    for path, content in outputs.items():
        path.write_text(content, encoding="utf-8")
        print(f"Generated {path.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
