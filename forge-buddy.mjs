#!/usr/bin/env node
/**
 * Claude Code Companion Forge
 *
 * 暴力破解 salt 使 Claude Code companion 生成指定种类/稀有度/属性的宠物，
 * 然后自动 patch cli.js。
 *
 * 用法:
 *   node forge-buddy.mjs --species penguin --rarity legendary --dump PATIENCE
 *   node forge-buddy.mjs --species cat --rarity epic --dump CHAOS --dry-run
 *   node forge-buddy.mjs --restore  (从 .bak 恢复)
 *
 * 算法来源: Claude Code cli.js 逆向 (FNV-1a + Mulberry32 PRNG)
 */

import { readFileSync, writeFileSync, existsSync, copyFileSync } from "fs";
import { join } from "path";
import { execSync } from "child_process";

// ─── 算法实现 ───

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

// ─── 常量 ───

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

const ORIGINAL_SALT = "friend-2026-401";
const SALT_LEN = ORIGINAL_SALT.length; // 15
const CHARSET = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ-_";

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

function generate(userId, salt) {
  const hash = fnv1a(userId + salt);
  const prng = mulberry32(hash);

  const rarity = getRarity(prng);
  const species = pickRandom(prng, SPECIES);
  const eye = pickRandom(prng, EYES);
  const hat = rarity === "common" ? "none" : pickRandom(prng, HATS);
  const shiny = prng() < 0.01;
  const { stats, peak, dump } = getStats(prng, rarity);

  return { rarity, species, eye, hat, shiny, stats, peak, dump };
}

// ─── 路径查找 ───

function findCliJs() {
  const candidates = [
    // npm global (Windows)
    join(process.env.APPDATA || "", "npm/node_modules/@anthropic-ai/claude-code/cli.js"),
    // npm global (Unix)
    "/usr/local/lib/node_modules/@anthropic-ai/claude-code/cli.js",
    "/usr/lib/node_modules/@anthropic-ai/claude-code/cli.js",
  ];

  // 也尝试 npm root -g 动态查找
  try {
    const npmRoot = execSync("npm root -g", { encoding: "utf8" }).trim();
    candidates.unshift(join(npmRoot, "@anthropic-ai/claude-code/cli.js"));
  } catch {}

  for (const p of candidates) {
    if (existsSync(p)) return p;
  }
  return null;
}

function getUserId() {
  const configPaths = [
    join(process.env.HOME || process.env.USERPROFILE || "", ".claude.json"),
  ];
  for (const p of configPaths) {
    if (existsSync(p)) {
      try {
        const config = JSON.parse(readFileSync(p, "utf8"));
        if (config.userID) return config.userID;
      } catch {}
    }
  }
  return null;
}

// ─── 暴力破解 ───

function bruteForce(userId, targetSpecies, targetRarity, targetDump) {
  let best = null;
  let bestScore = -Infinity;
  let count = 0;
  const found = [];

  // 尝试 "friend-2026-" + 3字符 变体
  const prefixes = ["friend-2026-", "buddy-2026--", "pal---2026--", "critter-2026"];

  for (const prefix of prefixes) {
    for (let i = 0; i < CHARSET.length; i++) {
      for (let j = 0; j < CHARSET.length; j++) {
        for (let k = 0; k < CHARSET.length; k++) {
          const salt = prefix + CHARSET[i] + CHARSET[j] + CHARSET[k];
          if (salt.length !== SALT_LEN) continue;
          count++;

          const result = generate(userId, salt);

          const speciesOk = !targetSpecies || result.species === targetSpecies;
          const rarityOk = !targetRarity || result.rarity === targetRarity;
          const dumpOk = !targetDump || result.dump === targetDump;

          if (speciesOk && rarityOk && dumpOk) {
            const nonDumpStats = STATS.filter((s) => s !== result.dump);
            const score = nonDumpStats.reduce((sum, s) => sum + result.stats[s], 0);

            if (score > bestScore) {
              bestScore = score;
              best = { salt, ...result };
            }
            found.push({ salt, score, ...result });
          }
        }
      }
    }
  }

  return { best, found: found.sort((a, b) => b.score - a.score), searched: count };
}

// ─── Patch ───

function patchCliJs(cliPath, oldSalt, newSalt) {
  const bakPath = cliPath + ".bak";

  // 备份（不覆盖已有备份）
  if (!existsSync(bakPath)) {
    copyFileSync(cliPath, bakPath);
    console.log(`  备份: ${bakPath}`);
  }

  let content = readFileSync(cliPath, "utf8");
  const count = content.split(oldSalt).length - 1;
  if (count === 0) {
    // 尝试在内容中查找任何 15 字符的已 patch salt
    console.error(`  错误: 未找到 salt "${oldSalt}"，可能已被 patch 过`);
    console.error(`  提示: 用 --restore 恢复后重试`);
    process.exit(1);
  }

  content = content.replace(oldSalt, newSalt);
  writeFileSync(cliPath, content, "utf8");

  // 验证
  const verify = readFileSync(cliPath, "utf8");
  if (!verify.includes(newSalt)) {
    console.error("  验证失败!");
    process.exit(1);
  }
  console.log(`  Patch 成功: ${oldSalt} → ${newSalt}`);
}

function restoreCliJs(cliPath) {
  const bakPath = cliPath + ".bak";
  if (!existsSync(bakPath)) {
    console.error("  没有找到备份文件 (.bak)");
    process.exit(1);
  }
  copyFileSync(bakPath, cliPath);
  console.log(`  已从备份恢复: ${bakPath}`);
}

// ─── 查找当前 salt ───

function findCurrentSalt(cliPath) {
  const content = readFileSync(cliPath, "utf8");
  if (content.includes(ORIGINAL_SALT)) return ORIGINAL_SALT;

  // 尝试查找已 patch 的 salt（搜索模式特征）
  // salt 出现在 userId 拼接处，格式固定
  const patterns = ["friend-2026-", "buddy-2026-", "pal---2026-", "critter-2026"];
  for (const prefix of patterns) {
    const idx = content.indexOf(prefix);
    if (idx !== -1) {
      return content.substring(idx, idx + SALT_LEN);
    }
  }
  return null;
}

// ─── CLI ───

function parseArgs() {
  const args = process.argv.slice(2);
  const opts = {};
  for (let i = 0; i < args.length; i++) {
    if (args[i] === "--species" && args[i + 1]) opts.species = args[++i];
    else if (args[i] === "--rarity" && args[i + 1]) opts.rarity = args[++i];
    else if (args[i] === "--dump" && args[i + 1]) opts.dump = args[++i];
    else if (args[i] === "--dry-run") opts.dryRun = true;
    else if (args[i] === "--restore") opts.restore = true;
    else if (args[i] === "--show") opts.show = true;
    else if (args[i] === "--help" || args[i] === "-h") opts.help = true;
  }
  return opts;
}

function printUsage() {
  console.log(`
Claude Code Companion Forge

用法:
  node forge-buddy.mjs --species <种类> [--rarity <稀有度>] [--dump <属性>] [--dry-run]
  node forge-buddy.mjs --show           查看当前宠物
  node forge-buddy.mjs --restore        恢复原始 cli.js

种类: ${SPECIES.join(", ")}
稀有度: ${RARITY_ORDER.join(", ")}
属性: ${STATS.join(", ")}

示例:
  node forge-buddy.mjs --species penguin --rarity legendary --dump PATIENCE
  node forge-buddy.mjs --species cat --rarity epic --dry-run
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

const cliPath = findCliJs();
if (!cliPath) {
  console.error("找不到 Claude Code cli.js，请确认已全局安装");
  process.exit(1);
}
console.log(`cli.js: ${cliPath}`);

if (opts.restore) {
  restoreCliJs(cliPath);
  process.exit(0);
}

const userId = getUserId();
if (!userId) {
  console.error("找不到 userID，请确认 ~/.claude.json 存在");
  process.exit(1);
}
console.log(`userID: ${userId.slice(0, 14)}...`);

// 显示当前宠物
const currentSalt = findCurrentSalt(cliPath);
if (currentSalt) {
  const current = generate(userId, currentSalt);
  printPet("当前宠物:", current);
}

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
if (opts.dump && !STATS.includes(opts.dump)) {
  console.error(`无效属性: ${opts.dump}\n可选: ${STATS.join(", ")}`);
  process.exit(1);
}

// 搜索
console.log(`\n搜索中: species=${opts.species} rarity=${opts.rarity || "any"} dump=${opts.dump || "any"} ...`);
const { best, found, searched } = bruteForce(userId, opts.species, opts.rarity, opts.dump);
console.log(`搜索 ${searched} 个 salt，找到 ${found.length} 个匹配`);

if (!best) {
  console.log("未找到匹配，尝试放宽条件（去掉 --rarity 或 --dump）");
  process.exit(1);
}

printPet("最佳匹配:", best);

// Top 5
if (found.length > 1) {
  console.log(`\n  Top ${Math.min(5, found.length)}:`);
  for (let i = 0; i < Math.min(5, found.length); i++) {
    const f = found[i];
    const nonDump = STATS.filter((s) => s !== f.dump).map((s) => `${s.slice(0, 3)}=${f.stats[s]}`);
    console.log(`  ${i + 1}. salt=${f.salt} ${f.eye} ${f.hat} ${f.shiny ? "✨" : ""} | ${nonDump.join(" ")}`);
  }
}

if (opts.dryRun) {
  console.log("\n  --dry-run 模式，未修改文件");
  process.exit(0);
}

// Patch
console.log("");
const activeSalt = currentSalt || ORIGINAL_SALT;
patchCliJs(cliPath, activeSalt, best.salt);
console.log("\n  重启 Claude Code 后生效");
