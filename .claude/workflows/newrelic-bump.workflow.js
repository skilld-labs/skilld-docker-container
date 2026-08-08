export const meta = {
  name: 'newrelic-bump',
  description: 'Bump the pinned NewRelic PHP agent version in scripts/makefile/newrelic.sh to the latest release, validate it loads, and prepare a commit following the repo NR: convention.',
  phases: [
    { title: 'Find', detail: 'latest NewRelic PHP agent version' },
    { title: 'Bump', detail: 'edit pin + validate' },
  ],
}

const LATEST = {
  type: 'object',
  required: ['version'],
  properties: {
    version: { type: 'string', description: 'e.g. 12.7.0.36' },
    releaseUrl: { type: 'string' },
    current: { type: 'string', description: 'version currently pinned in the repo' },
  },
}
const RESULT = {
  type: 'object',
  required: ['bumped', 'summary'],
  properties: {
    bumped: { type: 'boolean' },
    summary: { type: 'string' },
    commitMessage: { type: 'string' },
  },
}

// The harness invokes this with the workflow context (phase/agent/log helpers).
export async function run({ phase, agent, log }) {
  phase('Find')
  const latest = await agent(
    `Find the latest NewRelic PHP agent release version. Read the current pin from
scripts/makefile/newrelic.sh (the NEW_RELIC_AGENT_VERSION default). Determine the newest available
release version and its release-notes URL. Return version, releaseUrl, and current.`,
    { phase: 'Find', schema: LATEST },
  )
  log(`NewRelic agent: current ${latest?.current || '?'} → latest ${latest?.version || '?'}`)

  if (!latest?.version) {
    return { bumped: false, summary: 'Could not determine the latest NewRelic agent version; aborting.' }
  }
  if (latest.version === latest.current) {
    return { bumped: false, summary: `Already at the latest agent version (${latest.version}).` }
  }

  phase('Bump')
  const result = await agent(
    `Bump the NewRelic PHP agent to ${latest?.version}.
1. Edit the version string in scripts/makefile/newrelic.sh (and any matching version in .env.default or
   docker config if present). Make a minimal diff.
2. Run \`composer validate\`. If a stack is up, run \`make newrelic reload\` and confirm the agent loads
   (extension_loaded('newrelic') or docker compose logs php). If no stack is up, note that runtime
   validation was skipped.
3. Prepare a commit message in the repo's existing convention: "NR: <release-notes-url>"
   (see \`git log --oneline | grep '^... NR:'\`). Do NOT commit unless asked.
Return bumped, a summary, and the proposed commitMessage.`,
    { phase: 'Bump', schema: RESULT, agentType: 'dep-bumper' },
  )

  return { ...result, from: latest?.current, to: latest?.version, releaseUrl: latest?.releaseUrl }
}
