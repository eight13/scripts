#!/usr/bin/env node
/**
 * Claude Code Companion Forge
 *
 * 控制 Claude Code companion 的种类、稀有度、属性和语言。
 *
 * 原理:
 *   - 种类/稀有度: 写入 companionOverride 到 ~/.claude.json（原生支持，无需 patch）
 *   - 属性(stats): 由 hash(userId + SALT) 决定，通过 companionSeed + cli.js patch 控制
 *                   （仅 npm 安装版可用；standalone .exe 版无 cli.js，属性不可控）
 *   - 中文对话: 在 companion.personality 末尾注入中文指令
 *
 * 用法:
 *   node forge-buddy.mjs --species penguin --rarity legendary                    # 仅改种类/稀有度
 *   node forge-buddy.mjs --species penguin --rarity legendary --peak DEBUGGING   # 同时搜索最优属性
 *   node forge-buddy.mjs --show           查看当前宠物
 *   node forge-buddy.mjs --patch          CLI 更新后重新 patch（属性控制）
 *   node forge-buddy.mjs --restore        恢复原始状态
 *   node forge-buddy.mjs --name Moss      改名
 *   node forge-buddy.mjs --cn             仅注入中文指令
 *
 * 算法来源: Claude Code 源码 (FNV-1a + Mulberry32 PRNG)
 */

import { readFileSync, writeFileSync, existsSync } from "fs";
import { join } from "path";
import { execSync } from "child_process";

// ─── 算法实现（与 Claude Code Node.js 版一致）───

function fnv1a(str) {
  let h = 2166136261;
  for (let i = 0; i < str.length; i++) {
    h ^= str.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }
  return h >>> 0;
}

function mulberry32(seed) {
  let s = seed >>> 0;
  return function () {
    s |= 0;
    s = (s + 1831565813) | 0;
    let t = Math.imul(s ^ (s >>> 15), 1 | s);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

function pickRandom(prng, arr) {
  return arr[Math.floor(prng() * arr.length)];
}

// ─── 常量（与 Claude Code 源码同步）───

const SPECIES = [
  "duck", "goose", "blob", "cat", "dragon", "octopus", "owl", "penguin",
  "turtle", "snail", "ghost", "axolotl", "capybara", "cactus", "robot",
  "rabbit", "mushroom", "chonk",
];

const RARITY_WEIGHTS = { common: 60, uncommon: 25, rare: 10, epic: 4, legendary: 1 };
const RARITY_ORDER = ["common", "uncommon", "rare", "epic", "legendary"];
const STATS = ["DEBUGGING", "PATIENCE", "CHAOS", "WISDOM", "SNARK"];
const EYES = ["·", "✦", "×", "◉", "@", "°"];
const HATS = ["none", "crown", "tophat", "propeller", "halo", "wizard", "beanie", "tinyduck"];
const BASE_STATS = { common: 5, uncommon: 15, rare: 25, epic: 35, legendary: 50 };

const SALT = "friend-2026-401";

// ─── 生成逻辑 ───

function getRarity(prng) {
  let r = prng() * 100;
  for (const tier of RARITY_ORDER) {
    r -= RARITY_WEIGHTS[tier];
    if (r < 0) return tier;
  }
  return "common";
}

function getStats(prng, rarity) {
  const base = BASE_STATS[rarity];
  const peak = pickRandom(prng, STATS);
  let dump = pickRandom(prng, STATS);
  while (dump === peak) dump = pickRandom(prng, STATS);

  const result = {};
  for (const stat of STATS) {
    if (stat === peak) {
      result[stat] = Math.min(100, base + 50 + Math.floor(prng() * 30));
    } else if (stat === dump) {
      result[stat] = Math.max(1, base - 10 + Math.floor(prng() * 15));
    } else {
      result[stat] = base + Math.floor(prng() * 40);
    }
  }
  return { stats: result, peak, dump };
}

function generate(userId) {
  const hash = fnv1a(userId + SALT);
  const prng = mulberry32(hash);

  const rarity = getRarity(prng);
  const species = pickRandom(prng, SPECIES);
  const eye = pickRandom(prng, EYES);
  const hat = rarity === "common" ? "none" : pickRandom(prng, HATS);
  const shiny = prng() < 0.01;
  const { stats, peak, dump } = getStats(prng, rarity);

  return { rarity, species, eye, hat, shiny, stats, peak, dump };
}

// ─── 配置文件操作 ───

const HOME = process.env.HOME || process.env.USERPROFILE || "";
const CONFIG_PATH = join(HOME, ".claude.json");

function readConfig() {
  if (!existsSync(CONFIG_PATH)) {
    console.error(`找不到 ${CONFIG_PATH}`);
    process.exit(1);
  }
  return JSON.parse(readFileSync(CONFIG_PATH, "utf8"));
}

function writeConfig(config) {
  writeFileSync(CONFIG_PATH, JSON.stringify(config, null, 2), "utf8");
}

// ─── companionOverride 操作（种类/稀有度，原生支持）───

function applyOverride(species, rarity) {
  const config = readConfig();
  if (!config.companionOverride) config.companionOverride = {};
  config.companionOverride.species = species;
  config.companionOverride.rarity = rarity;
  writeConfig(config);
  console.log(`  写入 companionOverride: ${rarity} ${species}`);
}

function removeOverride() {
  const config = readConfig();
  if (config.companionOverride) {
    delete config.companionOverride;
    writeConfig(config);
    console.log("  已移除 companionOverride");
  } else {
    console.log("  没有 companionOverride 需要移除");
  }
}

// ─── companionSeed 操作（属性控制，需要 cli.js patch）───

function getCompanionUserId(config) {
  return config.companionSeed ?? config.oauthAccount?.accountUuid ?? config.userID ?? "anon";
}

function applySeed(seed) {
  const config = readConfig();
  config.companionSeed = seed;
  writeConfig(config);
  console.log(`  写入 companionSeed: ${seed}`);
}

function removeSeed() {
  const config = readConfig();
  if (config.companionSeed) {
    delete config.companionSeed;
    writeConfig(config);
    console.log("  已移除 companionSeed");
  } else {
    console.log("  没有 companionSeed 需要移除");
  }
}

// ─── CLI Patch 操作（属性控制，仅 npm 安装版）───

function findCliJs() {
  const candidates = [
    join(process.env.APPDATA || "", "npm/node_modules/@anthropic-ai/claude-code/cli.js"),
    join(HOME, ".npm-global/lib/node_modules/@anthropic-ai/claude-code/cli.js"),
  ];

  try {
    const npmRoot = execSync("npm root -g", { encoding: "utf8" }).trim();
    candidates.unshift(join(npmRoot, "@anthropic-ai/claude-code/cli.js"));
  } catch { /* ignore */ }

  for (const p of candidates) {
    if (existsSync(p)) return p;
  }
  return null;
}

const ORIGINAL_PATTERN = /function (\w+)\(\)\{let (\w)=(\w+)\(\);return \2\.oauthAccount\?\.accountUuid\?\?\2\.userID\?\?"anon"\}/;
const PATCHED_PATTERN = /function (\w+)\(\)\{let (\w)=(\w+)\(\);return \2\.companionSeed\?\?\2\.oauthAccount\?\.accountUuid\?\?\2\.userID\?\?"anon"\}/;

function checkPatchStatus(cliPath) {
  const code = readFileSync(cliPath, "utf8");
  if (PATCHED_PATTERN.test(code)) return "patched";
  if (ORIGINAL_PATTERN.test(code)) return "unpatched";
  return "unknown";
}

function patchCli(cliPath) {
  const code = readFileSync(cliPath, "utf8");

  if (PATCHED_PATTERN.test(code)) {
    console.log("  cli.js 已是 patched 状态");
    return true;
  }

  const match = code.match(ORIGINAL_PATTERN);
  if (!match) {
    console.error("  无法定位 companionUserId 函数，CLI 版本可能不兼容");
    return false;
  }

  const [original, funcName, varName, configFunc] = match;
  const patched = `function ${funcName}(){let ${varName}=${configFunc}();return ${varName}.companionSeed??${varName}.oauthAccount?.accountUuid??${varName}.userID??"anon"}`;

  writeFileSync(cliPath, code.replace(original, patched), "utf8");

  if (!PATCHED_PATTERN.test(readFileSync(cliPath, "utf8"))) {
    console.error("  patch 验证失败!");
    return false;
  }

  console.log(`  已 patch: ${funcName}() 添加 companionSeed 优先读取`);
  return true;
}

function unpatchCli(cliPath) {
  const code = readFileSync(cliPath, "utf8");
  const match = code.match(PATCHED_PATTERN);
  if (!match) {
    console.log("  cli.js 已是原始状态");
    return;
  }
  const [patched, funcName, varName, configFunc] = match;
  const original = `function ${funcName}(){let ${varName}=${configFunc}();return ${varName}.oauthAccount?.accountUuid??${varName}.userID??"anon"}`;
  writeFileSync(cliPath, code.replace(patched, original), "utf8");
  console.log("  已还原 cli.js");
}

// ─── Companion 中文指令 ───

const CN_TAG = "Always speaks in Chinese (中文).";

function patchCompanionLang() {
  const config = readConfig();
  if (!config.companion?.personality) {
    console.log("  没有 companion personality，跳过中文指令");
    return;
  }
  if (config.companion.personality.includes(CN_TAG)) {
    console.log("  personality 已包含中文指令");
    return;
  }
  const newP = config.companion.personality + " " + CN_TAG;
  if (newP.length > 200) {
    console.log(`  personality 超限 (${newP.length}/200)，需手动缩短`);
    return;
  }
  config.companion.personality = newP;
  writeConfig(config);
  console.log(`  已添加中文指令 (${newP.length}/200)`);
}

function unpatchCompanionLang() {
  const config = readConfig();
  if (!config.companion?.personality?.includes(CN_TAG)) return;
  config.companion.personality = config.companion.personality.replace(" " + CN_TAG, "");
  writeConfig(config);
  console.log("  已移除中文指令");
}

// ─── 改名 ───

function setName(name) {
  const config = readConfig();
  if (!config.companion) {
    console.log("  没有 companion 数据，请先启动 Claude Code 让宠物 hatching");
    return;
  }
  config.companion.name = name;
  writeConfig(config);
  console.log(`  companion 名字改为: ${name}`);
}

// ─── 暴力搜索 ───

function bruteForce(targetDump, targetPeak) {
  let best = null;
  let bestScore = -Infinity;
  let count = 0;
  const found = [];

  const MAX = 50_000_000;
  const REPORT_INTERVAL = 5_000_000;

  for (let n = 0; n < MAX; n++) {
    const uuid = n.toString(16).padStart(8, "0");
    count++;

    if (count % REPORT_INTERVAL === 0) {
      process.stdout.write(`  进度: ${(count / 1_000_000).toFixed(0)}M / ${MAX / 1_000_000}M  匹配: ${found.length}\r`);
    }

    // 搜索时只关心 stats（种类/稀有度由 companionOverride 控制）
    // 但仍需用完整 generate 推进 PRNG 状态到 stats 阶段
    const result = generate(uuid);

    const dumpOk = !targetDump || result.dump === targetDump;
    const peakOk = !targetPeak || result.peak === targetPeak;

    if (dumpOk && peakOk) {
      const nonDumpStats = STATS.filter((s) => s !== result.dump);
      const score = nonDumpStats.reduce((sum, s) => sum + result.stats[s], 0);

      if (score > bestScore) {
        bestScore = score;
        best = { uuid, ...result };
      }
      if (found.length < 20 || score > found[found.length - 1].score) {
        found.push({ uuid, score, ...result });
        if (found.length > 20) {
          found.sort((a, b) => b.score - a.score);
          found.length = 20;
        }
      }
    }
  }

  process.stdout.write("\n");
  return { best, found: found.sort((a, b) => b.score - a.score), searched: count };
}

// ─── CLI ───

function parseArgs() {
  const args = process.argv.slice(2);
  const opts = {};
  for (let i = 0; i < args.length; i++) {
    if (args[i] === "--species" && args[i + 1]) opts.species = args[++i];
    else if (args[i] === "--rarity" && args[i + 1]) opts.rarity = args[++i];
    else if (args[i] === "--dump" && args[i + 1]) opts.dump = args[++i];
    else if (args[i] === "--peak" && args[i + 1]) opts.peak = args[++i];
    else if (args[i] === "--name" && args[i + 1]) opts.name = args[++i];
    else if (args[i] === "--dry-run") opts.dryRun = true;
    else if (args[i] === "--restore") opts.restore = true;
    else if (args[i] === "--show") opts.show = true;
    else if (args[i] === "--patch") opts.patch = true;
    else if (args[i] === "--cn") opts.cn = true;
    else if (args[i] === "--help" || args[i] === "-h") opts.help = true;
  }
  return opts;
}

function printUsage() {
  console.log(`
Claude Code Companion Forge

用法:
  node forge-buddy.mjs --species <种类> --rarity <稀有度> [--peak <属性>] [--dump <属性>] [--dry-run]
  node forge-buddy.mjs --show           查看当前宠物
  node forge-buddy.mjs --patch          CLI 更新后重新 patch（属性控制）
  node forge-buddy.mjs --restore        恢复原始状态
  node forge-buddy.mjs --name <名字>    改名
  node forge-buddy.mjs --cn             注入中文对话指令

种类: ${SPECIES.join(", ")}
稀有度: ${RARITY_ORDER.join(", ")}
属性(peak/dump): ${STATS.join(", ")}

示例:
  node forge-buddy.mjs --species penguin --rarity legendary                        # 仅改种类/稀有度
  node forge-buddy.mjs --species penguin --rarity legendary --peak DEBUGGING       # + 搜索最优属性
  node forge-buddy.mjs --species cat --rarity epic --peak CHAOS --dump PATIENCE    # 完整指定
  node forge-buddy.mjs --name Moss --cn                                            # 改名 + 中文

工作原理:
  种类/稀有度 → companionOverride（原生支持，写配置即可，永不丢失）
  属性(stats) → companionSeed + cli.js patch（仅 npm 安装版；更新后需 --patch）
  中文对话    → personality 字段注入（永不丢失）
`);
}

function printPet(label, result) {
  const stars = { common: "★", uncommon: "★★", rare: "★★★", epic: "★★★★", legendary: "★★★★★" };
  console.log(`\n  ${label}`);
  console.log(`  种类: ${result.species}  稀有度: ${result.rarity} ${stars[result.rarity]}`);
  console.log(`  眼睛: ${result.eye}  帽子: ${result.hat}  闪光: ${result.shiny ? "是" : "否"}`);
  console.log(`  Peak: ${result.peak}  Dump: ${result.dump}`);
  for (const s of STATS) {
    const val = result.stats[s];
    const bar = "█".repeat(Math.floor(val / 5)) + "░".repeat(20 - Math.floor(val / 5));
    const tag = s === result.peak ? " ▲" : s === result.dump ? " ▼" : "";
    console.log(`  ${s.padEnd(10)} ${bar} ${val}${tag}`);
  }
}

// ─── Main ───

const opts = parseArgs();

if (opts.help) {
  printUsage();
  process.exit(0);
}

// 定位 cli.js
const cliPath = findCliJs();

// --name: 改名（独立使用时直接执行，组合使用时随写入阶段一起处理）
if (opts.name && !opts.species && !opts.cn && !opts.patch) {
  setName(opts.name);
  process.exit(0);
}

// --cn: 仅注入中文指令
if (opts.cn && !opts.species && !opts.patch) {
  patchCompanionLang();
  process.exit(0);
}

// --restore: 恢复原始状态
if (opts.restore) {
  removeOverride();
  removeSeed();
  unpatchCompanionLang();
  if (cliPath) unpatchCli(cliPath);
  console.log("\n  重启 Claude Code 后生效");
  process.exit(0);
}

// --patch: 重新 patch cli.js + 中文
if (opts.patch) {
  if (cliPath) {
    patchCli(cliPath);
  } else {
    console.log("  未找到 cli.js（standalone 版无需 patch，属性不可控）");
  }
  patchCompanionLang();
  process.exit(0);
}

// --show: 查看当前宠物
const config = readConfig();
console.log(`配置: ${CONFIG_PATH}`);

if (config.companionOverride) {
  console.log(`Override: ${config.companionOverride.rarity} ${config.companionOverride.species}`);
}
if (config.companionSeed) {
  console.log(`Seed: ${config.companionSeed}（属性控制）`);
}
if (cliPath) {
  console.log(`CLI: ${cliPath} [${checkPatchStatus(cliPath)}]`);
} else {
  console.log("CLI: standalone 版（无 cli.js）");
}

const currentUserId = getCompanionUserId(config);
const current = generate(currentUserId);
printPet("当前属性（hash 计算值）:", current);

if (opts.show) process.exit(0);

if (!opts.species) {
  printUsage();
  process.exit(0);
}

// 验证参数
if (!SPECIES.includes(opts.species)) {
  console.error(`无效种类: ${opts.species}\n可选: ${SPECIES.join(", ")}`);
  process.exit(1);
}
if (opts.rarity && !RARITY_ORDER.includes(opts.rarity)) {
  console.error(`无效稀有度: ${opts.rarity}\n可选: ${RARITY_ORDER.join(", ")}`);
  process.exit(1);
}
if (opts.peak && !STATS.includes(opts.peak)) {
  console.error(`无效属性: ${opts.peak}\n可选: ${STATS.join(", ")}`);
  process.exit(1);
}
if (opts.dump && !STATS.includes(opts.dump)) {
  console.error(`无效属性: ${opts.dump}\n可选: ${STATS.join(", ")}`);
  process.exit(1);
}
if (opts.peak && opts.dump && opts.peak === opts.dump) {
  console.error(`peak 和 dump 不能相同: ${opts.peak}`);
  process.exit(1);
}

// 搜索属性（如果指定了 peak 或 dump）
const wantStats = opts.peak || opts.dump;
let bestSeed = null;

if (wantStats) {
  if (!cliPath) {
    console.log("\n  ⚠ standalone 版无法控制属性，仅应用种类/稀有度");
  } else {
    console.log(`\n搜索属性: peak=${opts.peak || "any"} dump=${opts.dump || "any"} ...`);
    const { best, found, searched } = bruteForce(opts.dump, opts.peak);
    console.log(`搜索 ${searched.toLocaleString()} 个候选，找到 ${found.length} 个匹配`);

    if (best) {
      bestSeed = best;
      printPet("最佳属性:", best);

      if (found.length > 1) {
        console.log(`\n  Top ${Math.min(5, found.length)}:`);
        for (let i = 0; i < Math.min(5, found.length); i++) {
          const f = found[i];
          const nonDump = STATS.filter((s) => s !== f.dump).map((s) => `${s.slice(0,3)}=${f.stats[s]}`);
          console.log(`  ${i + 1}. seed=${f.uuid} | ${nonDump.join(" ")}`);
        }
      }
    } else {
      console.log("  未找到匹配，放宽条件试试");
    }
  }
}

if (opts.dryRun) {
  console.log("\n  --dry-run 模式，未修改任何文件");
  process.exit(0);
}

// 写入 companionOverride（种类/稀有度）
console.log("");
applyOverride(opts.species, opts.rarity || "legendary");

// 改名（组合使用时）
if (opts.name) setName(opts.name);

// 写入 companionSeed + patch cli.js（属性）
if (bestSeed && cliPath) {
  applySeed(bestSeed.uuid);
  const status = checkPatchStatus(cliPath);
  if (status === "unpatched") {
    if (!patchCli(cliPath)) {
      console.log("  ⚠ patch 失败，种类/稀有度已生效，但属性不可控");
    }
  }
}

// 中文指令（仅在指定 --cn 时注入）
if (opts.cn) patchCompanionLang();

console.log("\n  重启 Claude Code 后生效");
if (cliPath && bestSeed) console.log("  CLI 更新后需重新运行: node forge-buddy.mjs --patch");
