#!/usr/bin/env node
/**
 * Usage: node number-sentences.mjs <file> [--lines <start>-<end>]
 *
 * 対象範囲を文に分け、1行に1文ずつ「S<番号>\tL<行番号>\t<文>」の形で出力する。
 * サブエージェントが全文をルールに照らしたかを、check-coverage.mjsで番号の抜けとして検査するために使う。
 *
 * - 文は「。」「！」「？」（直後の閉じ括弧を含む）で区切る。区切りのない行は1行を1文とする
 * - 空行と、行全体がHTMLコメントの行は出力しない
 * - コードブロック内は、日本語を含む行（日本語のコメント）だけを出力する
 *
 * exit 0: 出力した
 * exit 2: 引数が不正
 */
import { readFileSync } from "node:fs";

const args = process.argv.slice(2);
const file = args[0];
const rangeIndex = args.indexOf("--lines");
const range = rangeIndex >= 0 ? args[rangeIndex + 1]?.match(/^(\d+)-(\d+)$/) : null;
if (!file || (rangeIndex >= 0 && !range)) {
  process.stderr.write("Usage: node number-sentences.mjs <file> [--lines <start>-<end>]\n");
  process.exit(2);
}
const [start, end] = range ? [Number(range[1]), Number(range[2])] : [1, Infinity];

const JAPANESE = /[\p{Script=Hiragana}\p{Script=Katakana}\p{Script=Han}]/u;
const SENTENCE = /[^。！？]*[。！？][」』）)]*|[^。！？]+$/g;

let inFence = false;
let n = 0;
readFileSync(file, "utf-8")
  .split("\n")
  .forEach((line, i) => {
    const lineNo = i + 1;
    const isFence = /^\s*(```|~~~)/.test(line);
    if (isFence) inFence = !inFence;
    if (lineNo < start || lineNo > end) return;
    if (isFence || line.trim() === "") return;
    if (/^\s*<!--.*-->\s*$/.test(line)) return;
    if (inFence && !JAPANESE.test(line)) return;
    for (const sentence of line.match(SENTENCE) ?? []) {
      if (sentence.trim() === "") continue;
      n += 1;
      process.stdout.write(`S${n}\tL${lineNo}\t${sentence.trim()}\n`);
    }
  });
