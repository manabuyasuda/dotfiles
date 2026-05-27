#!/usr/bin/env node
/**
 * Usage: node check-screenshots.js <_index.json のパス>
 *
 * componentNodes に登録されたノードIDのうち、screenshots/ に PNG が存在しないものを
 * JSON 配列で標準出力に出力する。
 *
 * exit 0: 不足なし（すべて揃っている）
 * exit 1: 不足あり（出力 JSON に取得対象が入っている）
 */
import { readFileSync, existsSync } from "node:fs";
import { resolve, dirname, join } from "node:path";

const indexPath = resolve(process.argv[2] ?? "");
if (!indexPath) {
  process.stderr.write(
    "Usage: node check-screenshots.js <_index.json path>\n"
  );
  process.exit(2);
}

const screenshotsDir = join(dirname(indexPath), "..", "screenshots");
const index = JSON.parse(readFileSync(indexPath, "utf-8"));

const missing = (index.componentNodes ?? []).filter((node) => {
  const filename = node.nodeId.replace(":", "-") + ".png";
  return !existsSync(join(screenshotsDir, filename));
});

process.stdout.write(JSON.stringify(missing, null, 2) + "\n");
process.exit(missing.length > 0 ? 1 : 0);
