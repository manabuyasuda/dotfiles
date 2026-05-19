#!/usr/bin/env node
/**
 * Usage: node update-pending-nodes.js <rawFile.xml> <_index.json path>
 *
 * sparse XML からノードIDを抽出して pendingNodes に追加する。
 * userSkippedNodes・fetchedNodes・既存 pendingNodes に含まれる ID はスキップする。
 * 同時に fetchedNodes への追加と pendingNodes からの削除も行う。
 *
 * exit 0: 成功
 * exit 1: エラー
 */
import { readFileSync, writeFileSync } from "node:fs";
import { resolve, basename } from "node:path";

const [rawFilePath, indexPath] = process.argv.slice(2).map((p) => resolve(p));

if (!rawFilePath || !indexPath) {
  process.stderr.write(
    "Usage: node update-pending-nodes.js <rawFile.xml> <_index.json>\n"
  );
  process.exit(1);
}

const content = readFileSync(rawFilePath, "utf-8");
const processedNodeId = basename(rawFilePath, ".xml").replace("-", ":");

// XML 中のすべての id="..." を抽出する
const allIds = [];
const idRegex = /\bid="([^"]+)"/g;
let match;
while ((match = idRegex.exec(content)) !== null) {
  allIds.push(match[1]);
}

const index = JSON.parse(readFileSync(indexPath, "utf-8"));

const skipped = new Set(index.userSkippedNodes ?? []);
const fetched = new Set(index.fetchedNodes ?? []);
const pending = new Set(index.pendingNodes ?? []);

let added = 0;
for (const id of allIds) {
  if (id === processedNodeId) continue;
  if (skipped.has(id) || fetched.has(id) || pending.has(id)) continue;
  pending.add(id);
  added++;
}

// 処理済みノードを pendingNodes から除外して書き戻す
index.pendingNodes = [...pending].filter((id) => id !== processedNodeId);

index.fetchedNodes ??= [];
if (!fetched.has(processedNodeId)) {
  index.fetchedNodes.push(processedNodeId);
}

writeFileSync(indexPath, JSON.stringify(index, null, 2) + "\n");
process.stdout.write(
  `pendingNodes に ${added} 件追加しました（処理済み: ${processedNodeId}）\n`
);
