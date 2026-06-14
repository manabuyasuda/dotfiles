#!/usr/bin/env node
/**
 * skills と agents の frontmatter・配置・命名・境界ルールを検証する。
 *
 * 目的: skill / agent の分類の一貫性を CI と pre-commit で強制し、
 * 人やエージェントの注意・記憶に依存せず再発を防ぐ。
 *
 * 検証する内容:
 *  - skill: SKILL.md の存在、name（ディレクトリ名と一致）、description の必須
 *  - skill: settings.json の skillOverrides との相互照合（登録漏れ・実体なしを検出）
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
  // frontmatter は先頭行が `---` で、次に現れる `---` 単独行で閉じる。
  // 文字列検索（indexOf('\n---')）だと本文中の `---` を終端と誤認するため、行単位で判定する。
  const lines = content.split('\n');
  if (lines[0].trim() !== '---') return null;
  let endIdx = -1;
  for (let i = 1; i < lines.length; i++) {
    if (/^---\s*$/.test(lines[i])) {
      endIdx = i;
      break;
    }
  }
  if (endIdx === -1) return null;
  const block = lines.slice(1, endIdx).join('\n');

  const fm = { name: undefined, hasDescription: false, description: '', tools: [] };
  let currentKey = null;

  for (const line of block.split('\n')) {
    const keyMatch = line.match(/^([A-Za-z][\w-]*):(.*)$/);
    const listMatch = line.match(/^\s+-\s+(.+?)\s*$/);

    if (keyMatch) {
      currentKey = keyMatch[1];
      const inlineValue = keyMatch[2].trim();
      if (currentKey === 'name') fm.name = inlineValue || undefined;
      if (currentKey === 'description') {
        fm.hasDescription = true;
        if (inlineValue && inlineValue !== '>' && inlineValue !== '|') fm.description += inlineValue + ' ';
      }
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
    } else if (currentKey === 'description' && line.trim()) {
      // description の折り畳み（>）の継続行を連結する
      fm.description += line.trim() + ' ';
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

// --- 自動起動の意図と settings の整合（設計判断用の情報） ---
// description が自動起動を促しているのに settings で明示起動専用（user-invocable-only）に
// している、という矛盾を検出する。どちらに揃えるかは運用の判断のため、exit には影響しない。
const AUTO_INVOKE_PATTERNS = [
  /積極的に(起動|提案)/,
  /明示的に[^。]{0,40}なくても/,
  /自動的に(起動|提案|呼び出)/,
  /自動で(起動|提案|呼び出|呼ばれ)/,
  /感じたら[^。]{0,30}(提案|起動)/,
];
// 自動起動の方針を運用判断として保留している既知スキル（snapshot）。
// ここに無い新規の矛盾は error にして、矛盾の放置を構造で禁止する。
// description の自動起動表現を消すか settings を変えたら、ここからも外す。
const KNOWN_AUTOINVOKE_CONFLICTS = new Set([
  'x-check-me',
  'x-designing-usecases',
  'x-figma-extract',
  'x-implementing-plan',
  'x-planning-implementation',
  'x-report-it',
  'x-teach-me',
]);
const notices = [];
const settingsPath = join(ROOT, 'claude/settings.json');
let skillOverrides = {};
let settingsLoaded = false;
if (existsSync(settingsPath)) {
  try {
    skillOverrides = JSON.parse(readFileSync(settingsPath, 'utf8')).skillOverrides || {};
    settingsLoaded = true;
  } catch {
    warnings.push('claude/settings.json をパースできませんでした');
  }
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
    // skillOverrides 登録漏れ: グローバル設定では全 skill を明示起動専用にする前提（README 参照）。
    // 新規 skill を追加して settings への登録を忘れると、グローバルの skill が意図せず自動起動して
    // プロジェクト固有 skill の自動起動を奪う。登録漏れを CI で止める。
    if (settingsLoaded && !(entry in skillOverrides)) {
      errors.push(`skills/${entry}: settings.json の skillOverrides に登録がありません。全 skill を明示起動専用（user-invocable-only）にする前提のため追加してください`);
    }
    if (skillOverrides[entry] === 'user-invocable-only' && AUTO_INVOKE_PATTERNS.some((p) => p.test(fm.description))) {
      if (KNOWN_AUTOINVOKE_CONFLICTS.has(entry)) {
        notices.push(`skills/${entry}: 既知の自動起動矛盾（方針を保留中）。description の自動起動表現を消したら KNOWN_AUTOINVOKE_CONFLICTS から外す`);
      } else {
        errors.push(`skills/${entry}: user-invocable-only（明示起動専用）なのに description が自動起動を促している。settings か description を揃える。運用判断で保留するなら KNOWN_AUTOINVOKE_CONFLICTS に追加する`);
      }
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

// --- skillOverrides の実体照合（settings にあるが skill がない＝タイポ・削除残骸） ---
if (settingsLoaded && existsSync(SKILLS_DIR)) {
  const skillDirs = new Set(listDirs(SKILLS_DIR));
  for (const key of Object.keys(skillOverrides)) {
    if (!skillDirs.has(key)) {
      errors.push(`settings.json skillOverrides:「${key}」に対応する skill が claude/skills/ にありません（タイポか削除残骸）。エントリを削除するか skill 名を直してください`);
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
if (notices.length) {
  console.log('ℹ 自動起動の意図と settings の整合（exit には影響しません。設計判断用）:');
  for (const n of notices) console.log(`  - ${n}`);
}
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
