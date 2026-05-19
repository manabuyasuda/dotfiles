#!/usr/bin/env node
/**
 * Usage: node check-pending.js <_index.json path>
 *
 * pendingNodes が空かどうかを確認する。
 *
 * exit 0: 空（全フェッチ完了）
 * exit 1: 残りあり（フェッチが必要）
 */
import { readFileSync } from "node:fs";
import { resolve } from "node:path";

const indexPath = resolve(process.argv[2] ?? "");
if (!indexPath) {
  process.stderr.write("Usage: node check-pending.js <_index.json path>\n");
  process.exit(2);
}

const index = JSON.parse(readFileSync(indexPath, "utf-8"));
const pending = index.pendingNodes ?? [];

process.stdout.write(JSON.stringify(pending, null, 2) + "\n");
process.exit(pending.length > 0 ? 1 : 0);
