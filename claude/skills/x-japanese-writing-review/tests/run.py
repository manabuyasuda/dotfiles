#!/usr/bin/env python3
"""x-japanese-writing-reviewのテストを実行し、結果を検査する。

  python3 tests/run.py run [--models opus,sonnet] [--filter REGEX] [--jobs N] [--all]
  python3 tests/run.py verify

テストは2種類ある。
- 校正のテスト（rule-*@opus, rule-*@sonnet）：ルールファイルごとに input.md を1つの claude -p セッションに渡し、
  SKILL.mdの手順で検知と修正をさせる。検知・変えない文・数値はスクリプトが、修正の質は判定エージェントが判定する
- 判定のテスト（judge/rule-*@opus）：expected.md の合格の例と不合格の例を、判定エージェントが正しく判定できるかを確かめる
run は、結果ファイルのハッシュが現在の依存ファイルと一致しないテストだけを実行する（--all で全件）。
verify はLLMを呼ばず、全テストが合格し、ハッシュが一致するかだけを検査する。CIは verify だけを実行する。
"""

import argparse
import hashlib
import json
import re
import shutil
import subprocess
import sys
import tempfile
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timezone
from pathlib import Path

TESTS_DIR = Path(__file__).resolve().parent
SKILL_DIR = TESTS_DIR.parent
RESULTS_PATH = TESTS_DIR / "results.json"
LOG_DIR = TESTS_DIR / ".logs"

# 実行時点の最新モデルで確かめるため、IDではなくエイリアスで指定する（ユーザー判断、2026-10-15）。
# 実際に使われたモデルIDは結果に記録する。
MODELS = ["opus", "sonnet"]
# 修正の質を判定するモデル。テスト対象のモデルによらず固定する。
JUDGE_MODEL = "opus"
# 文書が短いため、SKILL.mdの3周ではなく2周にする。1周では結果がばらつく（ユーザー判断、2026-10-15）。
ROUNDS = 2
# エージェントの判定はばらつくため、同じテストを2回実行し、両方とも合格したときだけ合格にする。
RUNS_PER_TEST = 2

RUN_TIMEOUT_SEC = 60 * 60
JUDGE_TIMEOUT_SEC = 20 * 60

def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def rule_headings(rule_path: Path) -> list[str]:
    return [line[3:].strip() for line in read(rule_path).splitlines() if line.startswith("## ")]


# ---------- ケースの読み込み ----------


def split_sections(doc: str) -> dict[str, str]:
    """input.md（または校正後の文書）を、`<!-- case:ID -->`の区切りでケースごとに分ける。"""
    pieces = re.split(r"^<!-- case:([\w-]+) -->$", doc, flags=re.M)
    return {pieces[i]: pieces[i + 1].strip() for i in range(1, len(pieces) - 1, 2)}


FENCE4 = re.compile(r"^(````+)(markdown|text)\n(.*?)\n\1\s*$", re.M | re.S)


def parse_examples(text: str) -> list[dict]:
    examples, last = [], 0
    for m in FENCE4.finditer(text):
        note = text[last:m.start()].strip()
        examples.append({"kind": m.group(2), "body": m.group(3), "note": note})
        last = m.end()
    return examples


def split_headings(text: str, level: int) -> tuple[str, list[tuple[str, str]]]:
    """指定した階層の見出しで分ける。例の中にも見出しを書くので、コードブロックの中の行は見出しとみなさない。"""
    head, parts, fence = [], [], None
    for line in text.splitlines():
        m = re.match(r"^(`{3,})", line)
        if m:
            if fence is None:
                fence = m.group(1)
            elif line.strip() == fence:
                fence = None
        if fence is None and re.match(rf"^{'#' * level} (?!#)", line):
            parts.append((line[level + 1:].strip(), []))
            continue
        (parts[-1][1] if parts else head).append(line)
    return "\n".join(head), [(title, "\n".join(body)) for title, body in parts]


def parse_expected(path: Path) -> dict[str, dict]:
    """expected.md をケースごとに読む。決まったラベルと見出しが欠けていたらエラーで止める。"""
    cases = {}
    path = path.resolve()
    for cid, body in split_headings(read(path), 2)[1]:
        head, subs = split_headings(body, 3)
        sub = {title: content.strip() for title, content in subs}
        labels: dict[str, list[str]] = {}
        for m in re.finditer(r"^- (ルール|検知する文|コードブロックの変更)：(.+)$", head, flags=re.M):
            labels.setdefault(m.group(1), []).append(m.group(2).strip())
        where = f"{path.relative_to(SKILL_DIR)} の {cid}"
        for need in ("ルール", "検知する文"):
            if need not in labels:
                sys.exit(f"error: {where} に「{need}」がありません")
        for need in ("誤りの箇所と理由", "修正の観点", "合格の例", "不合格の例"):
            if need not in sub:
                sys.exit(f"error: {where} に見出し「{need}」がありません")
        viewpoints = re.findall(r"^\d+\.\s*(.+)$", sub["修正の観点"], flags=re.M)
        good, bad = parse_examples(sub["合格の例"]), parse_examples(sub["不合格の例"])
        if not viewpoints or not good or not bad:
            sys.exit(f"error: {where} に、修正の観点・合格の例・不合格の例がそれぞれ1つ以上必要です")
        # 例は修正後のセクションだけ。保留を期待するケースは作らない（ユーザー判断、2026-10-19）。
        if any(e["kind"] != "markdown" for e in good + bad):
            sys.exit(f"error: {where} の合格の例と不合格の例は ````markdown で書いてください")
        cases[cid] = {
            "id": cid,
            "rule": labels["ルール"][0],
            # 1つの「検知する文」の中の「｜」は、どれか1つが検知されればよい候補の区切り。
            "must_flag": [s.split("｜") for s in labels["検知する文"]],
            "must_keep": [b["body"] for b in parse_examples(sub.get("変えない文", ""))],
            # 書き手に聞けばわかる事実。テストされるエージェントには、文書を書いた作業のコンテキストとして渡す。
            "context": sub.get("コンテキスト", ""),
            "code_blocks_may_change": labels.get("コードブロックの変更", [""])[0] == "可",
            "reason": sub["誤りの箇所と理由"],
            "viewpoints": viewpoints,
            "good": good,
            "bad": bad,
        }
    return cases


def load_tests() -> list[dict]:
    tests = []
    for case_dir in sorted(p for p in (TESTS_DIR / "rules").iterdir() if p.is_dir()):
        rule_path = SKILL_DIR / f"{case_dir.name}.md"
        headings = rule_headings(rule_path)
        sections = split_sections(read(case_dir / "input.md"))
        cases = parse_expected(case_dir / "expected.md")
        if set(sections) != set(cases):
            sys.exit(f"error: {case_dir.name} の input.md と expected.md のケースが一致しません："
                     f"{sorted(set(sections) ^ set(cases))}")
        covered = [c["rule"] for c in cases.values()]
        # ルールを追加したのにケースを書き忘れると、そのルールが検査されないまま合格してしまう。
        missing = [h for h in headings if h not in covered]
        unknown = [r for r in covered if r not in headings]
        if missing or unknown:
            sys.exit(f"error: {case_dir.name} とルールの見出しが一致しません\n  ケースがないルール: {missing}\n  存在しないルール: {unknown}")
        for c in cases.values():
            for keep in c["must_keep"]:
                if keep not in sections[c["id"]]:
                    sys.exit(f"error: {case_dir.name} の {c['id']} の変えない文が input.md にありません：{keep}")
        common = [read(Path(__file__)), read(rule_path), read(case_dir / "input.md"), read(case_dir / "expected.md")]
        base = {"name": case_dir.name, "rule_path": rule_path, "headings": headings, "sections": sections,
                "cases": cases, "input": read(case_dir / "input.md")}
        tests.append({**base, "id": case_dir.name, "kind": "review", "models": MODELS,
                      "deps": common + [read(SKILL_DIR / "SKILL.md"),
                                        *(read(p) for p in sorted((SKILL_DIR / "methods").glob("*.md")))]})
        tests.append({**base, "id": f"judge/{case_dir.name}", "kind": "judge", "models": [JUDGE_MODEL], "deps": common})
    return tests


def test_hash(test: dict, alias: str) -> str:
    return hashlib.sha256("\0".join([alias, *test["deps"]]).encode("utf-8")).hexdigest()


# ---------- 実行 ----------


def claude(prompt: str, alias: str, cwd: Path, add_dirs: list[Path], tools: list[str],
           schema: dict, timeout: int, extra: list[str] | None = None) -> dict:
    cmd = [
        "claude", "-p", prompt,
        "--model", alias,
        # ユーザー設定のhookやCLAUDE.mdが結果を左右しないよう、設定を読み込まない。
        "--setting-sources", "",
        "--no-session-persistence",
        "--output-format", "json",
        "--json-schema", json.dumps(schema, ensure_ascii=False),
        "--tools", ",".join(tools),
        *(arg for d in add_dirs for arg in ("--add-dir", str(d))),
        *(extra or []),
    ]
    proc = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, timeout=timeout)
    if proc.returncode != 0:
        raise RuntimeError(f"claude exited {proc.returncode}: {proc.stderr[-1000:]}{proc.stdout[-1000:]}")
    out = json.loads(proc.stdout)
    if out.get("is_error") or "structured_output" not in out:
        raise RuntimeError(f"claude returned no structured output: {proc.stdout[-1000:]}")
    return out


def copy_skill(dest: Path, rule_path: Path) -> Path:
    """テスト対象に読ませるファイルだけをコピーする。

    スキルのディレクトリ全体を読ませると、tests/ の期待する結果をエージェントが読めてしまう。
    """
    skill = dest / "skill"
    (skill / "methods").mkdir(parents=True)
    shutil.copy(SKILL_DIR / "SKILL.md", skill)
    shutil.copy(rule_path, skill)
    for p in (SKILL_DIR / "methods").glob("*.md"):
        shutil.copy(p, skill / "methods")
    return skill


FINDINGS_SCHEMA = {
    "type": "object",
    "properties": {
        "findings": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "round": {"type": "integer"},
                    "rule": {"type": "string"},
                    "quote": {"type": "string"},
                    "action": {"type": "string", "enum": ["fixed", "pending", "rejected"]},
                    "reason": {"type": "string"},
                },
                "required": ["round", "rule", "quote", "action", "reason"],
            },
        }
    },
    "required": ["findings"],
}


def review(test: dict, alias: str, log: dict) -> tuple[str, list[dict]]:
    with tempfile.TemporaryDirectory() as tmp:
        skill = copy_skill(Path(tmp), test["rule_path"])
        work = Path(tmp) / "work"
        work.mkdir()
        target = work / "target.md"
        target.write_text(test["input"], encoding="utf-8")
        # 通常は、文書を書いた作業のコンテキストの中でスキルを使う。テストではそのコンテキストを会話の代わりに渡す
        # （ユーザー判断、2026-10-19）。直し方そのものはコンテキストに書かない。
        context = work / "context.md"
        context.write_text("# この文書を書いた作業のコンテキスト\n\n" + "".join(
            f"## case:{cid}\n\n{c['context']}\n\n" for cid, c in test["cases"].items() if c["context"]),
            encoding="utf-8")
        # SKILL.mdはGit管理外のファイルを対象外にする。管理下にあるファイルとして渡す。
        subprocess.run(["git", "init", "-q"], cwd=work, check=True)
        subprocess.run(["git", "add", "target.md"], cwd=work, check=True)
        headings = "\n".join(f"- {h}" for h in test["headings"])
        prompt = (
            f"{skill / 'SKILL.md'}を読み、その手順どおりに{target}を校正してください。"
            "ただし、テストのため次の3点だけを変えてください。\n"
            f"- 使うルールファイルは{test['rule_path'].name}だけです。起動するサブエージェントは各周回で1つです\n"
            f"- 周回数は{ROUNDS}回です\n"
            f"- この文書は、{context}にある作業のコンテキストの中で書かれました。SKILL.mdの手順で会話を調べる場面では、"
            "会話の代わりにこのファイルを読んでください。見出しのcase:IDは、文書の`<!-- case:ID -->`の区切りに対応します。"
            "ユーザーへは確認できないので、コンテキストを読んでも決められない指摘だけを、修正せずに保留してください\n\n"
            "`<!-- case:... -->`の行は、テストの採点に使う区切りです。削除・変更・移動をしないでください。\n\n"
            "最後に、全周回でサブエージェントが返した指摘を1件ずつ、次の組で返してください。"
            "round（周回の番号）、rule（違反したルールの見出し）、quote（違反箇所を含む文を、その周回の開始時点の"
            "ファイルから1文字も変えずに抜き出した文字列）、action（Editで直したらfixed、修正せずに保留したらpending、"
            "違反ではないと判断して採用しなかったらrejected）、reason（修正した場合は修正内容。保留した場合は、保留の理由と、SKILL.mdの手順に従ってユーザーへ示す候補や提案。不採用の場合はその理由）。\n"
            f"ルールの見出しは次のとおりです。\n{headings}"
        )
        out = claude(prompt, alias, cwd=work, add_dirs=[skill],
                     tools=["Read", "Edit", "Bash", "Agent", "Glob", "Grep"], schema=FINDINGS_SCHEMA,
                     timeout=RUN_TIMEOUT_SEC,
                     extra=["--permission-mode", "acceptEdits", "--allowedTools", "Bash(git check-ignore:*)"])
        result = read(target)
    findings = out["structured_output"]["findings"]
    log.update({
        "models": list((out.get("modelUsage") or {}).keys()),
        "cost_usd": out.get("total_cost_usd"),
        "num_turns": out.get("num_turns"),
        "subagent_stats": {k: (out.get("subagent_stats") or {}).get(k) for k in ("spawned", "completed", "failed")},
        "findings": findings,
        "result": result,
    })
    return result, findings


def normalize(s: str) -> str:
    # 抜き出すときにエージェントが記法を落としても、同じ箇所として照合する。
    s = re.sub(r"[`*]", "", s)
    return "\n".join(re.sub(r"^\s*(?:#+|>|[-*]|\d+\.)\s*", "", line) for line in s.splitlines()).strip()


def overlaps(a: str, b: str) -> bool:
    a, b = normalize(a), normalize(b)
    return bool(a) and bool(b) and (a in b or b in a)


def numbers(text: str) -> set[str]:
    # 項目数（「次の2つ」）と番号付きの箇条書きの番号は、文書から数えて導けるので除く。
    text = re.sub(r"\d+(?:つ|点|項目)", "", text)
    text = re.sub(r"^\s*\d+\.\s", "", text, flags=re.M)
    return set(re.findall(r"\d+", text))


FENCE = re.compile(r"^```.*?^```", re.M | re.S)


def same_text(a: str, b: str) -> bool:
    # 記法と空白の変更（引用記法を外す、見出しの階層を変える、語の間を詰める）も修正なので、
    # normalize せず、空行と行末の空白の違いだけを無視して比べる。
    squash = lambda s: re.sub(r"[ \t]*\n(?:[ \t]*\n)*", "\n", s.strip())
    return squash(a) == squash(b)


def text_failures(case: dict, before: str, after: str) -> list[str]:
    """修正後の文書だけで判定できる条件を検査する。判定エージェントには判定させない。"""
    failures = []
    # 違反ではない文を書き換えると、書き手が意図した表現を失ってしまう。
    failures += [f"違反ではない文を書き換えた：{keep}" for keep in case["must_keep"] if keep not in after]
    # コンテキストにある数値は、書き手から得た情報なので、元の文書にある数値として扱う。
    added = numbers(after) - numbers(before) - numbers(case["context"])
    if added:
        failures.append(f"元の文書にない数値を加えた：{sorted(added)}")
    if not case["code_blocks_may_change"] and FENCE.findall(after) != FENCE.findall(before):
        failures.append("コードブロックの中身を変えた")
    return failures


def grade_case(case: dict, before: str, after: str | None, findings: list[dict]) -> tuple[list[str], dict | None]:
    """スクリプトで判定できる条件を検査し、修正の質を判定エージェントに渡す項目を返す。"""
    if after is None:
        return ["区切りの行が消え、セクションを特定できない"], None
    failures = []
    mine = [f for f in findings if f["rule"] == case["rule"]]
    hits = [f for f in mine if any(overlaps(alt, f["quote"]) for alts in case["must_flag"] for alt in alts)]
    for alts in case["must_flag"]:
        if not any(overlaps(alt, f["quote"]) for alt in alts for f in mine):
            failures.append(f"検知されなかった：{'｜'.join(alts)}")
    for keep in case["must_keep"]:
        if any(overlaps(keep, f["quote"]) and f["action"] != "rejected" for f in mine):
            failures.append(f"違反ではない文を検知した：{keep}")
    failures += text_failures(case, before, after)
    if failures:
        return failures, None

    # すべてのケースは、コンテキストを使えば直せる違反なので、保留も不合格にする（ユーザー判断、2026-10-19）。
    if same_text(after, before):
        reasons = [f["reason"] for f in hits if f["action"] == "pending"]
        return ["検知したが、直さなかった" + (f"（保留の理由：{reasons[0][:200]}）" if reasons else "")], None
    return [], judge_item(case, before, after, exclude=None)


def judge_item(case: dict, before: str, after: str, exclude: dict | None) -> dict:
    """判定エージェントに渡す1項目を作る。exclude の例は、判定の参考から外す（判定のテストで使う）。"""
    def fmt(examples):
        return [{"例": e["body"], "補足": e["note"]} for e in examples if e is not exclude]
    item = {
        "id": case["id"],
        "ルール": case["rule"],
        "文書を書いた作業のコンテキスト": case["context"] or "（なし）",
        "誤りの箇所と理由": case["reason"],
        "修正の観点": case["viewpoints"],
        "合格の例": fmt(case["good"]),
        "不合格の例": fmt(case["bad"]),
        "修正前": before,
        "修正後": after,
    }
    return item


JUDGE_SCHEMA = {
    "type": "object",
    "properties": {
        "items": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "id": {"type": "string"},
                    "results": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {"ok": {"type": "boolean"}, "reason": {"type": "string"}},
                            "required": ["ok", "reason"],
                        },
                    },
                },
                "required": ["id", "results"],
            },
        }
    },
    "required": ["items"],
}


# 判定エージェントは、項目が多いと一部の項目の結果を返さないことがある。返らなかった項目だけを問い直す。
JUDGE_RETRIES = 2


def judge(items: list[dict], rule_path: Path, log: dict) -> tuple[dict[str, list[dict]], float]:
    verdicts, cost = {}, 0.0
    pending = items
    for _ in range(1 + JUDGE_RETRIES):
        got, c = judge_once(pending, rule_path, log)
        cost += c
        verdicts.update({k: v for k, v in got.items()})
        pending = [it for it in items if len(verdicts.get(it["id"]) or []) != len(it["修正の観点"])]
        if not pending:
            break
    return verdicts, cost


def judge_once(items: list[dict], rule_path: Path, log: dict) -> tuple[dict[str, list[dict]], float]:
    prompt = (
        "文章の校正結果を採点してください。"
        f"採点に使うルールは{rule_path.name}にあります。必要なら読んでください。\n\n"
        "次の各項目は、1つのケースの校正結果です。「文書を書いた作業のコンテキスト」と「誤りの箇所と理由」を読んだうえで、"
        "「修正前」と「修正後」を比べ、「修正の観点」の1つずつについて満たしているか（ok）と理由（reason）を、"
        "観点と同じ順で返してください。コンテキストにある事実は、元の文書にない情報には当たりません。\n"
        "合格の例と不合格の例は、判定の参考です。表現が合格の例と違っても、観点を満たしていればokです。"
        "修正後の文書が、ルールに沿っているかで判定してください。"
        "修正後の文書には、同じルールファイルのほかのルールに沿った書き換えが含まれることがあります"
        "（例：並列の事柄を箇条書きにする）。その書き換えがルールファイルに沿っていて、事実を失っていなければ、"
        "不合格の理由にしないでください。\n\n"
        + json.dumps(items, ensure_ascii=False, indent=2)
    )
    with tempfile.TemporaryDirectory() as tmp:
        shutil.copy(rule_path, tmp)
        out = claude(prompt, JUDGE_MODEL, cwd=Path(tmp), add_dirs=[], tools=["Read"],
                     schema=JUDGE_SCHEMA, timeout=JUDGE_TIMEOUT_SEC)
    verdicts = {v["id"]: v["results"] for v in out["structured_output"]["items"]}
    log.setdefault("judge", []).append(verdicts)
    return verdicts, out.get("total_cost_usd") or 0


def viewpoint_failures(item: dict, results: list[dict] | None) -> list[str]:
    if not results or len(results) != len(item["修正の観点"]):
        return ["判定の結果が観点の数と一致しない"]
    return [f"観点を満たしていない：{vp}（{r['reason']}）" for vp, r in zip(item["修正の観点"], results) if not r["ok"]]


def run_review(test: dict, alias: str, log: dict) -> dict[str, list[str]]:
    result, findings = review(test, alias, log)
    after_sections = split_sections(result)
    case_failures, items = {}, []
    for cid, case in test["cases"].items():
        fl, item = grade_case(case, test["sections"][cid], after_sections.get(cid), findings)
        case_failures[cid] = fl
        if item:
            items.append(item)
    if items:
        verdicts, cost = judge(items, test["rule_path"], log)
        log["judge_cost_usd"] = cost
        for item in items:
            case_failures[item["id"]] += viewpoint_failures(item, verdicts.get(item["id"]))
    return case_failures


def run_judge_test(test: dict, alias: str, log: dict) -> dict[str, list[str]]:
    """合格の例を合格、不合格の例を不合格と判定できるかを確かめる。判定する例は、参考の例から外す。"""
    items, expected = [], {}
    case_failures = {cid: [] for cid in test["cases"]}
    for cid, case in test["cases"].items():
        before = test["sections"][cid]
        for label, examples, should_pass in (("合格", case["good"], True), ("不合格", case["bad"], False)):
            for n, ex in enumerate(examples, 1):
                # スクリプトで検出できる誤りは、校正のテストでも判定エージェントに渡らない。
                # 判定エージェントのテストからも外し、合格の例がスクリプトで落ちる場合は例の誤りとして報告する。
                if text_failures(case, before, ex["body"]):
                    if should_pass:
                        case_failures[cid].append(f"{cid}/{label}{n}がスクリプトの判定で不合格になる："
                                                  f"{'; '.join(text_failures(case, before, ex['body']))}")
                    continue
                item = judge_item(case, before, ex["body"], exclude=ex)
                item["id"] = f"{cid}/{label}{n}"
                items.append(item)
                expected[item["id"]] = (cid, should_pass)
    verdicts, cost = judge(items, test["rule_path"], log)
    log["cost_usd"] = cost
    for item in items:
        cid, should_pass = expected[item["id"]]
        fl = viewpoint_failures(item, verdicts.get(item["id"]))
        if should_pass and fl:
            case_failures[cid].append(f"{item['id']}を不合格と判定した：{'; '.join(fl)}")
        elif not should_pass and not fl:
            case_failures[cid].append(f"{item['id']}を合格と判定した")
        elif not should_pass and not any(f.startswith("観点を満たしていない") for f in fl):
            case_failures[cid].append(f"{item['id']}：{'; '.join(fl)}")
    return case_failures


def run_one(test: dict, alias: str, attempt: int) -> tuple[dict[str, list[str]], dict]:
    log = {"test": test["id"], "alias": alias, "attempt": attempt}
    started = time.time()
    try:
        runner = run_review if test["kind"] == "review" else run_judge_test
        case_failures = runner(test, alias, log)
    except Exception as e:  # 実行の失敗も不合格として記録し、ほかのテストは続ける
        case_failures = {cid: [f"実行に失敗した：{str(e)[:300]}"] for cid in test["cases"]}
    log.update({"case_failures": case_failures, "seconds": round(time.time() - started)})
    path = LOG_DIR / alias / f"{test['id'].replace('/', '__')}.{attempt}.json"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(log, ensure_ascii=False, indent=2), encoding="utf-8")
    return case_failures, log


def load_results() -> dict:
    return json.loads(read(RESULTS_PATH)) if RESULTS_PATH.exists() else {}


def save_results(results: dict) -> None:
    RESULTS_PATH.write_text(json.dumps(dict(sorted(results.items())), ensure_ascii=False, indent=2) + "\n",
                            encoding="utf-8")


def cmd_run(args) -> int:
    if not shutil.which("claude"):
        sys.exit("error: claude が見つかりません")
    tests = [t for t in load_tests() if re.search(args.filter, t["id"])]
    results = load_results()
    jobs = []
    for t in tests:
        for alias in t["models"]:
            if alias not in args.models.split(","):
                continue
            key = f"{t['id']}@{alias}"
            h = test_hash(t, alias)
            prev = results.get(key)
            if not args.all and prev and prev["hash"] == h and prev["passed"]:
                continue
            jobs.append((t, alias, key, h))
    print(f"{len(jobs)}件のテストを{RUNS_PER_TEST}回ずつ実行します", flush=True)
    outcomes: dict[str, list] = {key: [] for _, _, key, _ in jobs}
    with ThreadPoolExecutor(max_workers=args.jobs) as pool:
        futures = {pool.submit(run_one, t, alias, n): (key, h)
                   for t, alias, key, h in jobs for n in range(1, RUNS_PER_TEST + 1)}
        for f in as_completed(futures):
            key, h = futures[f]
            case_failures, log = f.result()
            outcomes[key].append((case_failures, log))
            bad = {c: fl for c, fl in case_failures.items() if fl}
            cost = (log.get("cost_usd") or 0) + (log.get("judge_cost_usd") or 0)
            print(f"{'PASS' if not bad else 'FAIL'} {key} {log['seconds']}s ${cost:.2f}", flush=True)
            for c, fl in bad.items():
                print(f"    {c}: {'; '.join(fl)}", flush=True)
            if len(outcomes[key]) == RUNS_PER_TEST:
                failed_cases = sorted({c for cf, _ in outcomes[key] for c, fl in cf.items() if fl})
                results[key] = {
                    "hash": h,
                    "passed": not failed_cases,
                    "failed_cases": failed_cases,
                    "models": sorted({m for _, lg in outcomes[key] for m in lg.get("models", [])}),
                    "ran_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
                }
                # 長時間の実行が途中で止まっても、終わったテストの結果を失わないよう毎回書き込む。
                save_results(results)
    failed = [k for k in outcomes if not results[k]["passed"]]
    print(f"\n不合格：{len(failed)}件" + "".join(f"\n  {k}: {results[k]['failed_cases']}" for k in sorted(failed)))
    return 1 if failed else 0


def cmd_verify(_args) -> int:
    results = load_results()
    problems, expected_keys = [], set()
    for t in load_tests():
        for alias in t["models"]:
            key = f"{t['id']}@{alias}"
            expected_keys.add(key)
            r = results.get(key)
            if r is None:
                problems.append(f"未実行：{key}")
            elif r["hash"] != test_hash(t, alias):
                problems.append(f"結果が古い（依存ファイルが変わった）：{key}")
            elif not r["passed"]:
                problems.append(f"不合格：{key} {r['failed_cases']}")
    problems += [f"存在しないテストの結果：{k}" for k in sorted(set(results) - expected_keys)]
    if problems:
        print("x-japanese-writing-reviewのテスト結果が、現在のファイルと一致しません。")
        print("python3 claude/skills/x-japanese-writing-review/tests/run.py run を実行し、")
        print("全件合格した tests/results.json をコミットしてください。\n")
        print("\n".join(problems))
        return 1
    print(f"OK：{len(expected_keys)}件のテスト結果が現在のファイルと一致し、すべて合格しています")
    return 0


def main() -> int:
    p = argparse.ArgumentParser()
    sub = p.add_subparsers(dest="cmd", required=True)
    r = sub.add_parser("run")
    r.add_argument("--models", default=",".join(MODELS))
    r.add_argument("--filter", default="")
    r.add_argument("--jobs", type=int, default=4)
    r.add_argument("--all", action="store_true", help="合格済みのテストも再実行する")
    sub.add_parser("verify")
    args = p.parse_args()
    return cmd_run(args) if args.cmd == "run" else cmd_verify(args)


if __name__ == "__main__":
    sys.exit(main())
