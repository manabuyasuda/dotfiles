#!/usr/bin/env node
/**
 * Usage: node check-coverage.mjs <numbered-file> <response-file>
 *
 * number-sentences.mjsの出力にある番号（S1, S2, …）が、サブエージェントの返答に
 * すべて行頭の番号として現れるかを検査する。抜けた番号を1行にまとめて出力する。
 *
 * exit 0: 抜けなし
 * exit 1: 抜けあり
 * exit 2: 引数が不正
 */
import { readFileSync } from "node:fs";

const [numberedFile, responseFile] = process.argv.slice(2);
if (!numberedFile || !responseFile) {
  process.stderr.write("Usage: node check-coverage.mjs <numbered-file> <response-file>\n");
  process.exit(2);
}

const expected = readFileSync(numberedFile, "utf-8")
  .split("\n")
  .map((line) => line.match(/^S(\d+)\t/)?.[1])
  .filter(Boolean);
// 箇条書きの記号や太字の記号が行頭に付いた返答も、番号として数える
const answered = new Set(
  readFileSync(responseFile, "utf-8")
    .split("\n")
    .map((line) => line.match(/^[\s\-*|#>]*S(\d+)\b/)?.[1])
    .filter(Boolean),
);

const missing = expected.filter((id) => !answered.has(id));
if (missing.length > 0) {
  process.stdout.write(`missing: ${missing.map((id) => `S${id}`).join(",")}\n`);
  process.exit(1);
}
process.stdout.write(`ok: ${expected.length}\n`);
