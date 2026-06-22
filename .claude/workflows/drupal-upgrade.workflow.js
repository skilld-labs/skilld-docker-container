export const meta = {
  name: 'drupal-upgrade',
  description: 'Transitional Drupal 11 upgrade: check the druxxy gate, bump core constraints, remove modules dropped from D11 core, update rector, then iterate to a clean upgrade_status — all in an isolated worktree.',
  phases: [
    { title: 'Gate', detail: 'check druxxy D11 availability' },
    { title: 'Apply', detail: 'composer constraints + remove ckeditor/color/seven + rector bump' },
    { title: 'Validate', detail: 'upgrade_status + rector + cinsp, iterate until ready' },
  ],
}

// --- schemas ---
const GATE = {
  type: 'object',
  required: ['blocked', 'reason'],
  properties: {
    blocked: { type: 'boolean' },
    reason: { type: 'string' },
    druxxyLatest: { type: 'string' },
    workaround: { type: 'string', description: 'e.g. temporarily set PROFILE_NAME=standard' },
  },
}
const APPLY = {
  type: 'object',
  required: ['composerResolved', 'summary'],
  properties: {
    composerResolved: { type: 'boolean' },
    summary: { type: 'string' },
    removedModules: { type: 'array', items: { type: 'string' } },
    openProblems: { type: 'array', items: { type: 'string' } },
  },
}
const VERDICT = {
  type: 'object',
  required: ['ready', 'blockers'],
  properties: {
    ready: { type: 'boolean' },
    blockers: { type: 'array', items: { type: 'string' } },
    autoFixable: { type: 'array', items: { type: 'string' } },
  },
}

// The harness invokes this with the workflow context (phase/agent/log/budget helpers).
export async function run({ phase, agent, log, budget }) {
  // --- Gate: is D11 unblocked? ---
  phase('Gate')
  const gate = await agent(
    `Determine whether a Drupal 11 upgrade is currently unblocked for the skilld-docker-container repo.
Run \`composer show skilldlabs/druxxy --all\` (the default install profile) and check whether any
release allows drupal/core ^11. Also skim composer.json require/require-dev for other obvious D11
blockers. Return blocked=true if druxxy (or core) cannot resolve on ^11, with a one-line reason and,
if blocked, a workaround (e.g. temporarily set PROFILE_NAME=standard on the throwaway branch).`,
    { phase: 'Gate', schema: GATE },
  )
  if (gate?.blocked) {
    log(`D11 gate BLOCKED: ${gate.reason}. Proceeding on the throwaway branch with workaround: ${gate.workaround || 'PROFILE_NAME=standard'}.`)
  }

  // --- Apply the transitional changes in an isolated worktree ---
  phase('Apply')
  const apply = await agent(
    `In an isolated git worktree, apply the TRANSITIONAL Drupal 11 changes from docs/upgrading.md:
1. composer.json: set drupal/core-composer-scaffold and drupal/core-vendor-hardening to "^10.3.1 || ^11";
   bump skilldlabs/druxxy to a D11-capable release IF ${gate?.blocked ? 'one exists (it may not — if blocked, leave druxxy and instead set PROFILE_NAME=standard in .env.default for validation only)' : 'available'}.
2. Remove drupal/ckeditor, drupal/color, drupal/seven. git grep for stragglers; switch admin theme to claro.
3. Bump palantirnet/drupal-rector (from ^0.20.3) and add Drupal11SetList to rector.php ONLY if the
   installed rector release exposes that class.
4. Re-verify the drupal/default_content patch still applies; drop it if upstreamed.
5. Run \`composer update --with-all-dependencies\` (via the php container) and report whether it resolved.
Make minimal, reviewable edits. Return composerResolved, a summary, the removed modules, and any open problems.`,
    { phase: 'Apply', schema: APPLY, isolation: 'worktree' },
  )
  log(`Apply: ${apply?.summary || 'no result'}`)

  // --- Validate and iterate to ready ---
  phase('Validate')
  let verdict = null
  const MAX_ITERS = budget.total ? 6 : 3
  for (let i = 1; i <= MAX_ITERS; i++) {
    verdict = await agent(
      `Validate Drupal upgrade-readiness of the current worktree. Run \`make upgradestatusval\` (authority),
\`make drupalrectorval\`, and \`make cinsp\`. Report ready=true only if upgrade_status prints no FILE:
lines. List remaining blockers (custom-code deprecations, by file) and which are rector-auto-fixable.`,
      { phase: 'Validate', label: `validate#${i}`, schema: VERDICT, agentType: 'upgrade-validator' },
    )
    if (verdict?.ready) { log(`Ready after ${i} iteration(s).`); break }
    if (!verdict?.blockers?.length) { log('No blockers reported but not marked ready — stopping to avoid a loop.'); break }
    log(`Iteration ${i}: ${verdict.blockers.length} blocker(s). Attempting fixes.`)
    await agent(
      `Fix these Drupal 11 deprecations in custom code only (web/modules/custom, web/themes/custom):
${verdict.blockers.map((b, n) => `${n + 1}. ${b}`).join('\n')}
Prefer \`vendor/bin/rector process web/modules/custom web/themes/custom\` for the auto-fixable ones,
then hand-edit the rest. Do not touch contrib/core. Keep edits minimal.`,
      { phase: 'Validate', label: `fix#${i}`, isolation: 'worktree' },
    )
  }

  return {
    gate,
    apply,
    finalVerdict: verdict,
    done: !!verdict?.ready,
    note: 'Definition of done is a green D11 review app — open an MR and run build:review + the test:* jobs.',
  }
}
