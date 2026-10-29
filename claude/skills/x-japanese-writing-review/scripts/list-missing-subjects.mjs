#!/usr/bin/env node
/**
 * Usage: node list-missing-subjects.mjs <elements-file>
 *
 * 要素の表（`S<番号> | <述語> | <主体> | …`の形の行）から、主体が`なし`の述語を
 * 1行に1つ「S<番号>\t<述語>」の形で出力する。
 * 主語の省略をサブエージェントの判断に任せると見逃すため、主体の欠けをここで機械的に抜き出す。
 *
 * exit 0: 出力した（0件を含む）
 * exit 2: 引数が不正
 */
import { readFileSync } from "node:fs";

const [elementsFile] = process.argv.slice(2);
if (!elementsFile) {
  process.stderr.write("Usage: node list-missing-subjects.mjs <elements-file>\n");
  process.exit(2);
}

for (const line of readFileSync(elementsFile, "utf-8").split("\n")) {
  const cells = line
    .replace(/^\s*\|/, "")
    .split("|")
    .map((cell) => cell.trim());
  if (!/^S\d+$/.test(cells[0] ?? "")) continue;
  const [id, predicate, subject] = cells;
  // 述語が`なし`の行は見出しのような述語のない文なので、主体の欠けとして数えない
  if (predicate !== "なし" && subject === "なし") process.stdout.write(`${id}\t${predicate}\n`);
}
