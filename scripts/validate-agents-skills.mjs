#!/usr/bin/env node
/**
 * skills と agents の frontmatter・配置・命名・境界ルールを検証する。
 *
 * 目的: skill / agent の分類の一貫性を CI と pre-commit で強制し、
 * 人やエージェントの注意・記憶に依存せず再発を防ぐ。
 *
 * 検証する内容:
 *  - skill: SKILL.md の存在、name（ディレクトリ名と一致）、description の必須
 *  - agent: name・description の必須、公式非サポートの固定ファイル名の検出、
 *           境界ルール（agent は AskUserQuestion を持てない＝対話は skill の責務）
 *  - 未知ツール名・README 索引の漏れは警告（exit code には影響しない）
 *
 * 終了コード: エラーが 1 件でもあれば 1、なければ 0。
 */
import { readFileSync, readdirSync, existsSync, statSync } from 'node:fs';
import { join, dirname, basename } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT = join(__dirname, '..');
const SKILLS_DIR = join(ROOT, 'claude/skills');
const AGENTS_DIR = join(ROOT, 'claude/agents');

const errors = [];
const warnings = [];

// Claude Code 標準ツール。MCP（mcp__...）と Bash()/Skill() 等の引数付き形式は別途許容する。
const KNOWN_TOOLS = new Set([
  'Bash', 'Read', 'Write', 'Edit', 'MultiEdit', 'Glob', 'Grep', 'LS',
  'AskUserQuestion', 'WebFetch', 'WebSearch', 'Skill', 'Agent', 'Task',
  'TaskCreate', 'TaskUpdate', 'TaskList', 'NotebookEdit', 'TodoWrite',
]);

function toolBase(tool) {
  return tool.replace(/\(.*\)$/, '').trim();
}

function isKnownTool(tool) {
  if (tool.startsWith('mcp__')) return true; // MCP ツール・ワイルドカード
  return KNOWN_TOOLS.has(toolBase(tool));
}

/**
 * frontmatter から name / description の有無 / tools を抽出する簡易パーサ。
 * 完全な YAML パースはせず、検証に必要なフィールドだけを取り出す。
 */
function parseFrontmatter(content) {
  if (!content.startsWith('---')) return null;
  const end = content.indexOf('\n---', 3);
  if (end === -1) return null;
  const block = content.slice(3, end);

  const fm = { name: undefined, hasDescription: false, tools: [] };
  let currentKey = null;

  for (const line of block.split('\n')) {
    const keyMatch = line.match(/^([A-Za-z][\w-]*):(.*)$/);
    const listMatch = line.match(/^\s+-\s+(.+?)\s*$/);

    if (keyMatch) {
      currentKey = keyMatch[1];
      const inlineValue = keyMatch[2].trim();
      if (currentKey === 'name') fm.name = inlineValue || undefined;
      if (currentKey === 'description') fm.hasDescription = true;
      if (
        (currentKey === 'tools' || currentKey === 'allowed-tools') &&
        inlineValue &&
        inlineValue !== '>' &&
        inlineValue !== '|'
      ) {
        // インライン形式（tools: Read, Grep）に対応する
        for (const tool of inlineValue.split(',')) {
          const trimmed = tool.trim();
          if (trimmed) fm.tools.push(trimmed);
        }
      }
    } else if (listMatch && (currentKey === 'tools' || currentKey === 'allowed-tools')) {
      fm.tools.push(listMatch[1].trim());
    }
  }
  return fm;
}

function listDirs(dir) {
  return readdirSync(dir).filter((e) => statSync(join(dir, e)).isDirectory());
}

function walkMarkdown(dir) {
  const out = [];
  for (const entry of readdirSync(dir)) {
    const p = join(dir, entry);
    if (statSync(p).isDirectory()) out.push(...walkMarkdown(p));
    else if (entry.endsWith('.md')) out.push(p);
  }
  return out;
}

// --- skills の検証 ---
if (existsSync(SKILLS_DIR)) {
  for (const entry of listDirs(SKILLS_DIR)) {
    const skillFile = join(SKILLS_DIR, entry, 'SKILL.md');
    if (!existsSync(skillFile)) {
      errors.push(`skills/${entry}: SKILL.md がありません`);
      continue;
    }
    const fm = parseFrontmatter(readFileSync(skillFile, 'utf8'));
    if (!fm) {
      errors.push(`skills/${entry}/SKILL.md: frontmatter がありません`);
      continue;
    }
    if (!fm.name) {
      errors.push(`skills/${entry}/SKILL.md: name がありません`);
    } else if (fm.name !== entry) {
      errors.push(`skills/${entry}/SKILL.md: name「${fm.name}」がディレクトリ名「${entry}」と一致しません`);
    }
    if (!fm.hasDescription) {
      errors.push(`skills/${entry}/SKILL.md: description がありません`);
    }
    for (const tool of fm.tools) {
      if (!isKnownTool(tool)) warnings.push(`skills/${entry}/SKILL.md: 未知のツール「${tool}」`);
    }
  }
}

// --- agents の検証 ---
if (existsSync(AGENTS_DIR)) {
  for (const file of walkMarkdown(AGENTS_DIR)) {
    const rel = file.slice(ROOT.length + 1);
    const fname = basename(file);

    // 公式は agents/<name>.md または agents/<subfolder>/<any>.md を認識し、
    // 識別は frontmatter の name のみで決まる。SUBAGENT.md / SKILL.md のような
    // スキル流用の固定ファイル名は公式非サポートで将来壊れうるため禁止する。
    if (fname === 'SUBAGENT.md' || fname === 'SKILL.md') {
      errors.push(`${rel}: agents/ 配下の固定名「${fname}」は公式非サポートです。<name>.md 形式にしてください`);
    }

    const fm = parseFrontmatter(readFileSync(file, 'utf8'));
    if (!fm) {
      errors.push(`${rel}: frontmatter がありません`);
      continue;
    }
    if (!fm.name) errors.push(`${rel}: name がありません`);
    if (!fm.hasDescription) errors.push(`${rel}: description がありません`);

    // 境界ルール: agent は独立コンテキストで動くため、ユーザーとの対話に向かない。
    // 対話（AskUserQuestion）が要るなら skill にすべきという分類の境界を強制する。
    if (fm.tools.some((tool) => toolBase(tool) === 'AskUserQuestion')) {
      errors.push(`${rel}: agent に AskUserQuestion は許可されません（対話は skill の責務です）`);
    }
    for (const tool of fm.tools) {
      if (!isKnownTool(tool)) warnings.push(`${rel}: 未知のツール「${tool}」`);
    }
  }
}

// --- skills/README.md の索引整合（警告） ---
const readmePath = join(SKILLS_DIR, 'README.md');
if (existsSync(readmePath)) {
  const readme = readFileSync(readmePath, 'utf8');
  for (const entry of listDirs(SKILLS_DIR)) {
    if (!readme.includes(entry)) {
      warnings.push(`skills/README.md: 「${entry}」が索引に載っていません`);
    }
  }
}

// --- 結果出力 ---
if (warnings.length) {
  console.warn('⚠ 警告:');
  for (const w of warnings) console.warn(`  - ${w}`);
}
if (errors.length) {
  console.error('✖ エラー:');
  for (const e of errors) console.error(`  - ${e}`);
  console.error(`\n${errors.length} 件のエラーがあります。skill / agent の分類規約に違反しています。`);
  process.exit(1);
}
console.log(`✓ 検証に通りました（skills・agents の frontmatter・配置・境界ルール）。警告 ${warnings.length} 件。`);
