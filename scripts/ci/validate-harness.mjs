#!/usr/bin/env node
// Static gate for the docs + .claude/ agent harness (Tier 0 of docs/testing.md).
// Pure Node (ESM), no external deps — runs in node:lts-alpine (the sniffers:harness CI job)
// or locally via `make harnessval`. Exits non-zero on any violation.

import { readFileSync, existsSync, readdirSync, statSync } from 'node:fs';
import { join, dirname, normalize, basename, extname } from 'node:path';
import { pathToFileURL } from 'node:url';
import { execFileSync } from 'node:child_process';

const ROOT = process.cwd();
const problems = [];
const fail = (check, msg) => problems.push(`${check}: ${msg}`);
let checks = 0;
const did = (check, msg) => { checks++; if (process.env.VERBOSE) console.log(`  ok ${check} — ${msg}`); };

const read = (p) => readFileSync(join(ROOT, p), 'utf8');
const exists = (p) => existsSync(join(ROOT, p));

function walk(dir, exts) {
  const out = [];
  const abs = join(ROOT, dir);
  if (!existsSync(abs)) return out;
  for (const name of readdirSync(abs)) {
    const rel = join(dir, name);
    const st = statSync(join(ROOT, rel));
    if (st.isDirectory()) out.push(...walk(rel, exts));
    else if (!exts || exts.includes(extname(name))) out.push(rel);
  }
  return out;
}

// ---------------------------------------------------------------------------
// T0.1 — Markdown relative links resolve
// ---------------------------------------------------------------------------
function checkLinks() {
  const files = [
    ...walk('docs', ['.md']),
    ...walk('.claude', ['.md']),
    'AGENTS.md', 'CLAUDE.md', 'CONTRIBUTING.md', 'README.md',
  ].filter(exists);
  const linkRe = /\]\((?!https?:\/\/|mailto:|#)([^)#]+)(?:#[^)]*)?\)/g;
  for (const f of files) {
    const base = dirname(f);
    const body = read(f);
    let m;
    while ((m = linkRe.exec(body))) {
      const target = normalize(join(base, m[1]));
      if (!exists(target)) fail('T0.1', `${f} → broken link "${m[1]}"`);
    }
    did('T0.1', f);
  }
}

// ---------------------------------------------------------------------------
// T0.2 — settings.json valid + permissions.allow is non-empty strings
// ---------------------------------------------------------------------------
function checkSettings() {
  const p = '.claude/settings.json';
  if (!exists(p)) return fail('T0.2', `${p} missing`);
  let json;
  try { json = JSON.parse(read(p)); }
  catch (e) { return fail('T0.2', `${p} invalid JSON: ${e.message}`); }
  const allow = json?.permissions?.allow;
  if (!Array.isArray(allow) || allow.length === 0) return fail('T0.2', `${p}: permissions.allow must be a non-empty array`);
  for (const a of allow) if (typeof a !== 'string' || !a.trim()) fail('T0.2', `${p}: bad allow entry ${JSON.stringify(a)}`);
  did('T0.2', p);
}

// ---------------------------------------------------------------------------
// T0.3 — Workflows: syntax-valid ES modules exporting meta{name,description} + run()
// ---------------------------------------------------------------------------
async function checkWorkflows() {
  const files = walk('.claude/workflows', ['.js', '.mjs']);
  if (!files.length) return fail('T0.3', 'no workflow files found');
  for (const f of files) {
    try { execFileSync('node', ['--check', join(ROOT, f)], { stdio: 'pipe' }); }
    catch (e) {
      if (e.code !== 'EPERM') {
        fail('T0.3', `${f} syntax error: ${String(e.stderr || e).split('\n')[0]}`);
        continue;
      }
    }
    try {
      const mod = await import(pathToFileURL(join(ROOT, f)).href);
      if (!mod.meta || typeof mod.meta.name !== 'string' || typeof mod.meta.description !== 'string')
        fail('T0.3', `${f}: must export meta with string name+description`);
      if (typeof mod.run !== 'function')
        fail('T0.3', `${f}: must export an async run() entry point`);
    } catch (e) { fail('T0.3', `${f}: import failed: ${e.message}`); }
    did('T0.3', f);
  }
}

// ---------------------------------------------------------------------------
// T0.4 — Skill/agent frontmatter (name+description; agents also tools); name matches path
// ---------------------------------------------------------------------------
function frontmatter(body) {
  const m = body.match(/^---\r?\n([\s\S]*?)\r?\n---/);
  if (!m) return null;
  const fm = {};
  for (const line of m[1].split(/\r?\n/)) {
    const mm = line.match(/^([A-Za-z_]+):\s*(.*)$/);
    if (mm) fm[mm[1]] = mm[2].trim();
  }
  return fm;
}
function checkFrontmatter() {
  for (const f of walk('.claude/skills', ['.md']).filter((p) => basename(p) === 'SKILL.md')) {
    const fm = frontmatter(read(f));
    if (!fm) { fail('T0.4', `${f}: missing frontmatter`); continue; }
    if (!fm.name) fail('T0.4', `${f}: missing name`);
    if (!fm.description) fail('T0.4', `${f}: missing description`);
    const dir = basename(dirname(f));
    if (fm.name && fm.name !== dir) fail('T0.4', `${f}: name "${fm.name}" != dir "${dir}"`);
    did('T0.4', f);
  }
  for (const f of walk('.claude/agents', ['.md'])) {
    const fm = frontmatter(read(f));
    if (!fm) { fail('T0.4', `${f}: missing frontmatter`); continue; }
    if (!fm.name) fail('T0.4', `${f}: missing name`);
    if (!fm.description) fail('T0.4', `${f}: missing description`);
    if (!fm.tools) fail('T0.4', `${f}: agent missing tools`);
    const stem = basename(f, '.md');
    if (fm.name && fm.name !== stem) fail('T0.4', `${f}: name "${fm.name}" != file "${stem}"`);
    did('T0.4', f);
  }
}

// ---------------------------------------------------------------------------
// T0.5 — Doc ↔ reality cross-checks
// ---------------------------------------------------------------------------
function realMakeTargets() {
  const set = new Set();
  // Match rule definitions `name:` / `name::` but not `name :=` variable assignments.
  const re = /^([A-Za-z0-9][A-Za-z0-9_-]*):(?!=)/gm;
  // Scan all scripts/**/*.mk so opt-in helper targets (e.g. multisite `split`) count as real.
  const mkFiles = ['Makefile', ...walk('scripts', ['.mk'])];
  for (const f of mkFiles) {
    if (!exists(f)) continue;
    let m; const body = read(f);
    while ((m = re.exec(body))) set.add(m[1]);
  }
  return set;
}
function makeTokensInCodeSpans(body) {
  const tokens = new Set();
  // Strip escaped backticks, then match fenced (```) blocks and inline (`) spans
  // separately so prose between two code blocks is never mistaken for a span.
  const cleanBody = body.replace(/\\`/g, '');
  const codeRe = /`{3,}([\s\S]*?)`{3,}|`([^`]+)`/g;
  let match;
  while ((match = codeRe.exec(cleanBody))) {
    const inner = match[1] || match[2];
    if (!inner) continue;
    const mr = /\bmake\s+([a-z][a-z0-9_-]*)/g;
    let sub;
    while ((sub = mr.exec(inner))) tokens.add(sub[1]);
  }
  return tokens;
}
// Strip shell/YAML `#` comments (respecting quotes) so a variable that appears
// only in a comment doesn't count as "referenced" by runtime config.
function stripHashComments(body) {
  return body
    .split('\n')
    .map((line) => {
      let quote = null;
      for (let i = 0; i < line.length; i++) {
        const ch = line[i];
        if ((ch === '"' || ch === "'") && line[i - 1] !== '\\') {
          quote = quote === ch ? null : (quote || ch);
        }
        if (ch === '#' && !quote) return line.slice(0, i);
      }
      return line;
    })
    .join('\n');
}
function checkDocReality() {
  const targets = realMakeTargets();
  // (a) make targets referenced in docs must exist
  const docFiles = ['AGENTS.md', 'CLAUDE.md', 'CONTRIBUTING.md', ...walk('docs', ['.md'])].filter(exists);
  for (const f of docFiles) {
    for (const t of makeTokensInCodeSpans(read(f)))
      if (!targets.has(t)) fail('T0.5a', `${f}: \`make ${t}\` is not a real target`);
    did('T0.5a', f);
  }
  // (b) make targets the CI-pipeline doc cites must actually appear in .gitlab-ci.yml,
  //     except the local-only aggregators (CI runs their decomposed sub-jobs, not these).
  if (exists('docs/ci-pipeline.md') && exists('.gitlab-ci.yml')) {
    const ci = read('.gitlab-ci.yml');
    const localAggregators = new Set(['tests', 'sniffers']);
    for (const t of makeTokensInCodeSpans(read('docs/ci-pipeline.md')))
      if (!localAggregators.has(t) && !ci.includes(`make ${t}`))
        fail('T0.5b', `docs/ci-pipeline.md cites \`make ${t}\` but no "make ${t}" in .gitlab-ci.yml`);
    did('T0.5b', '.gitlab-ci.yml');
  }
  // (c) key user-facing review-app variables are documented and backed by runtime config.
  const required = [
    'REVIEW_DOMAIN', 'THEME_PATH', 'STORYBOOK_PATH', 'RA_BASIC_AUTH',
    'TEST_UPDATE_DEPLOYMENTS', 'GITLAB_PROJECT_ACCESS_TOKEN', 'GITLAB_PROJECT_BASIC_AUTH',
    'RUN_PATCHVAL_CI_JOB', 'NEW_RELIC_LICENSE_KEY', 'IMAGE_PHP',
  ];
  if (exists('docs/review-apps.md')) {
    const doc = read('docs/review-apps.md');
    const runtimeFiles = [
      '.gitlab-ci.yml', '.env.default', 'Makefile',
      ...walk('scripts/makefile'), ...walk('docker'),
    ].filter((f) => exists(f) && statSync(join(ROOT, f)).isFile());
    const runtimeConfig = runtimeFiles.map((f) => stripHashComments(read(f))).join('\n');
    for (const v of required) {
      if (!doc.includes(v)) fail('T0.5c', `review-apps.md does not document CI var ${v}`);
      if (!runtimeConfig.includes(v)) fail('T0.5c', `${v} listed as required but not referenced in runtime config`);
    }
    did('T0.5c', 'review-apps vars');
  }
}

// ---------------------------------------------------------------------------
// T0.6 — EOF newline on new tree files (covers make newlineeof's blind spot)
// ---------------------------------------------------------------------------
function checkEof() {
  const files = [
    ...walk('docs'), ...walk('.claude'), ...walk('scripts/ci'),
    'AGENTS.md', 'scripts/makefile/worktree.mk', 'scripts/makefile/validate.mk',
  ].filter((f) => exists(f) && statSync(join(ROOT, f)).isFile());
  for (const f of files) {
    const buf = readFileSync(join(ROOT, f));
    if (buf.length && buf[buf.length - 1] !== 0x0a) fail('T0.6', `${f}: no trailing newline`);
    did('T0.6', f);
  }
}

// ---------------------------------------------------------------------------
// T0.7 — .claude/README.md mentions every skill/agent/workflow on disk
// ---------------------------------------------------------------------------
function checkSelfConsistency() {
  const p = '.claude/README.md';
  if (!exists(p)) return fail('T0.7', `${p} missing`);
  const readme = read(p);
  const names = [
    ...walk('.claude/skills', ['.md']).filter((f) => basename(f) === 'SKILL.md').map((f) => basename(dirname(f))),
    ...walk('.claude/agents', ['.md']).map((f) => basename(f, '.md')),
    ...walk('.claude/workflows', ['.js', '.mjs']).map((f) => basename(f)),
  ];
  for (const n of names) if (!readme.includes(n)) fail('T0.7', `${p} does not mention "${n}"`);
  did('T0.7', `${names.length} components`);
}

// ---------------------------------------------------------------------------
async function main() {
  checkLinks();
  checkSettings();
  await checkWorkflows();
  checkFrontmatter();
  checkDocReality();
  checkEof();
  checkSelfConsistency();

  if (problems.length) {
    console.error(`\n✗ harness static gate: ${problems.length} problem(s) across ${checks} checks:\n`);
    for (const p of problems) console.error(`  - ${p}`);
    process.exit(1);
  }
  console.log(`✓ harness static gate: all ${checks} checks passed.`);
}

main().catch((e) => { console.error(e); process.exit(2); });
