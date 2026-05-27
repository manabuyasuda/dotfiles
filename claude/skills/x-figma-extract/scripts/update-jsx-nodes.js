#!/usr/bin/env node
/**
 * Usage: node update-jsx-nodes.js <rawFile.txt> <_index.json path>
 *
 * .txt (JSX) から data-node-id を抽出して _index.json の jsxNodes に書き込む。
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
    "Usage: node update-jsx-nodes.js <rawFile.txt> <_index.json>\n"
  );
  process.exit(1);
}

const content = readFileSync(rawFilePath, "utf-8");
const rootNodeId = basename(rawFilePath, ".txt").replace("-", ":");

// JSX の開始タグから data-node-id / data-name ペアを抽出する
// [^<>]* は改行を含む任意の文字にマッチする（<> は属性値に現れない前提）
const nodes = [];
const tagRegex = /<\w[^<>]*data-node-id="[^"]*"[^<>]*>/g;
let match;
while ((match = tagRegex.exec(content)) !== null) {
  const tag = match[0];
  const nodeIdMatch = /data-node-id="([^"]+)"/.exec(tag);
  const nameMatch = /data-name="([^"]+)"/.exec(tag);
  if (nodeIdMatch) {
    nodes.push({
      nodeId: nodeIdMatch[1],
      name: nameMatch ? nameMatch[1] : null,
    });
  }
}

const index = JSON.parse(readFileSync(indexPath, "utf-8"));

index.jsxNodes ??= {};
index.jsxNodes[rootNodeId] = nodes;

index.fetchedNodes ??= [];
if (!index.fetchedNodes.includes(rootNodeId)) {
  index.fetchedNodes.push(rootNodeId);
}

index.pendingNodes = (index.pendingNodes ?? []).filter(
  (id) => id !== rootNodeId
);

writeFileSync(indexPath, JSON.stringify(index, null, 2) + "\n");
process.stdout.write(
  `jsxNodes[${rootNodeId}]: ${nodes.length} ノードを記録しました\n`
);
