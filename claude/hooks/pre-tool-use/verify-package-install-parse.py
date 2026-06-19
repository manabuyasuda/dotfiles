#!/usr/bin/env python3
# =============================================================================
# pre-tool-use/verify-package-install-parse.py
#   verify-package-install.sh の判定ロジック本体。
#   標準入力でシェルコマンド文字列を受け取り、bashlex でAST解析し、
#   実行される install 系コマンド (npm install / pnpm add / yarn add /
#   sfw <pm> ...) のパッケージリストを抽出して標準出力に書き出す。
#
#   出力フォーマット:
#     PM=<npm|pnpm|yarn>
#     PKG=<package-spec>
#     PKG=<package-spec>
#     ...
#   検知対象が無い場合は何も出力せず exit 0。
#   bashlex が import できないときは exit 2（呼び出し側がフォールバックする）。
# =============================================================================

import sys


def _extract_words(node):
    """ASTノードを再帰的に走査し、CommandNode の word リストを (cmd_words, ...) で返す。"""
    results = []
    kind = getattr(node, 'kind', None)
    if kind == 'command':
        words = []
        for part in getattr(node, 'parts', []):
            if getattr(part, 'kind', None) == 'word':
                # コマンド置換 (`$(...)`, ` `` `) や変数展開を含む word は安全のため除外。
                # AST 内の word は raw 文字列を持つが、展開結果は実行時依存なので扱わない。
                # bashlex は word の中に command-substitution part を入れることがあるため、
                # その場合は word をスキップする。
                substitution = False
                for sub in getattr(part, 'parts', []):
                    sub_kind = getattr(sub, 'kind', None)
                    if sub_kind in ('commandsubstitution', 'processsubstitution'):
                        substitution = True
                        break
                if substitution:
                    # コマンド置換自体は別 CommandNode として再帰で拾われるため、ここでは無視する
                    continue
                words.append(part.word)
        if words:
            results.append(words)
    # 子要素を再帰
    for attr in ('parts', 'list', 'command'):
        child = getattr(node, attr, None)
        if child is None:
            continue
        if isinstance(child, list):
            for c in child:
                results.extend(_extract_words(c))
        else:
            results.extend(_extract_words(child))
    return results


def _strip_sfw(words):
    """先頭が sfw なら剥がす。"""
    if words and words[0] == 'sfw':
        return words[1:]
    return words


def _detect_pm(words):
    """(pm, subcmd_index) を返す。対象外なら None。"""
    if len(words) < 3:
        # 最低 [pm, subcmd, pkg] の 3 トークン必要
        return None
    pm, sub = words[0], words[1]
    if pm == 'npm' and sub in ('install', 'i'):
        return ('npm', 2)
    if pm == 'pnpm' and sub == 'add':
        return ('pnpm', 2)
    if pm == 'yarn' and sub == 'add':
        return ('yarn', 2)
    return None


def _extract_packages(words, start):
    """サブコマンド以降からフラグを除いたパッケージ指定リストを返す。"""
    pkgs = []
    for arg in words[start:]:
        if arg.startswith('-'):
            continue
        pkgs.append(arg)
    return pkgs


def main():
    try:
        import bashlex
    except ImportError:
        sys.exit(2)

    source = sys.stdin.read()
    if not source.strip():
        return

    try:
        trees = bashlex.parse(source)
    except Exception:
        # パース失敗時はフォールバックさせるため exit 2
        sys.exit(2)

    detected_pm = None
    all_pkgs = []
    for tree in trees:
        for cmd_words in _extract_words(tree):
            stripped = _strip_sfw(cmd_words)
            pm_info = _detect_pm(stripped)
            if pm_info is None:
                continue
            pm, start = pm_info
            pkgs = _extract_packages(stripped, start)
            if not pkgs:
                continue
            detected_pm = pm
            all_pkgs.extend(pkgs)

    if detected_pm is None or not all_pkgs:
        return

    sys.stdout.write(f'PM={detected_pm}\n')
    for p in all_pkgs:
        sys.stdout.write(f'PKG={p}\n')


if __name__ == '__main__':
    main()
