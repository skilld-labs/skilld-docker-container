# Testing & validation

How to validate this template — both the **project** (Drupal/Docker/Makefile/CI machinery) and the
**agent harness** (`.claude/`) — before merging changes. Three tiers, increasing cost; the merge gate
at the bottom says which must pass.

The existing `make sniffers`/`make tests` cover the Drupal code. This page adds the **Tier 0 static
gate** for the docs and harness (which `sniffers` does not touch: `clang` is a no-op without
`config/sync`, `phpcs` only sniffs `web/{modules,themes}/custom`, and `newlineeof` only checks
`.env.default`).

## Tier 0 — Static gate (no Docker)

`scripts/ci/validate-harness.mjs` (Node, no deps). Run it:

```sh
node scripts/ci/validate-harness.mjs   # directly (needs node)
make harnessval                        # or containerised (node:lts-alpine, no local node needed)
```

In GitLab CI it runs as the **`sniffers:harness`** job (`image: node:lts-alpine`). The lightweight
GitHub Actions gate ([`.github/workflows/validation.yml`](../.github/workflows/validation.yml)) runs the
same Node validator plus the basic `make clang` / `make compval` / `make phpcs` / `make newlineeof`
sniffer set on pull requests. It checks:

| ID | Check |
| --- | --- |
| T0.1 | Every relative Markdown link in `docs/`, `AGENTS.md`, `CLAUDE.md`, `CONTRIBUTING.md`, `README.md`, `.claude/**` resolves |
| T0.2 | `.claude/settings.json` is valid JSON with a non-empty `permissions.allow` |
| T0.3 | Each `.claude/workflows/*.js` is a valid ES module exporting `meta{name,description}` + an async `run()` |
| T0.4 | Each skill/agent has frontmatter (`name`+`description`; agents also `tools`); `name` matches its path |
| T0.5 | Doc↔reality: every `` `make X` `` in the docs is a real target; CI-doc targets exist in `.gitlab-ci.yml`; key CI vars are documented in `review-apps.md` and used in CI |
| T0.6 | `AGENTS.md` and new files under `docs/`, `.claude/`, `scripts/` end with a newline |
| T0.7 | `.claude/README.md` mentions every skill/agent/workflow on disk |

**Negative test** (prove the gate bites): add a broken link or a fake `` `make nope` `` to a scratch
file and confirm the gate exits non-zero.

## Tier 1 — Harness functional (live-invoke)

Actually run each harness artifact and check behavior. Run anything that edits files in a **throwaway
git worktree** and discard it.

**Skills** — invoke `/<name>` and verify:
- `review-app-triage` maps a failing job → `make` target, names the first error, proposes a fix; nothing destructive.
- `drupal-upgrade` checks the **druxxy gate first**, reports BLOCKED (`v1.5.1 → core ^10.6`), offers the `PROFILE_NAME=standard` workaround; no unprompted core bump.
- `dep-bump` (NewRelic) edits only the pin in `scripts/makefile/newrelic.sh`, one dependency, validates.
- `backlog-grooming` reads `gh` (no writes), classifies into buckets, regenerates `docs/backlog.md`.
- `observability-up` prints log commands (Tier 1) and flags the PR #466 dependency for traces.

**Workflows** — run via the Workflow tool (throwaway worktree, discard):
- `drupal-upgrade` → Gate `blocked:true`, Apply in an isolated worktree, Validate spawns `upgrade-validator`, no commits.
- `newrelic-bump` → Find current vs latest; equal → `bumped:false`; else proposes an `NR: <url>` message, no commit.

**Subagents** — invoke via the Agent tool:
- `upgrade-validator` runs the gates, reports READY/NOT-READY with file-level blockers; no `composer.json` edits.
- `ci-log-analyzer` is read-only; names job + first error + repro command.
- `dep-bumper` does one pin and refuses a core-major jump.

## Tier 2 — Project functional (Docker) + regression

On a Docker host. Because docs/harness changes touch no runtime code, **results must match a `master`
baseline.**

```sh
make all            # T2.1 build: site installs; `make info` gives a reachable URL + logins
make sniffers       # T2.2
make tests          # T2.3 full suite (cinsp, rector, upgrade_status, behat, watchdog, …) — green
```

- **T2.3** compare `make tests` output to the same run on `master` → identical (no regression).
- **T2.4 worktree isolation** — in two `git worktree`s: `make worktree-name` then `make all`; assert
  distinct `COMPOSE_PROJECT_NAME`/network/containers, both URLs up at once; `make clean` both. See
  [parallel-environments.md](parallel-environments.md).
- **T2.5 Makefile regression** — `make help` lists `worktree-name`; `make worktree-name` executes
  (explicit rule beats the `%: ; @:` catch-all) and edits only `.env`.

## Merge gate

Merge a docs/harness PR (e.g. #468) only when **all** hold:

1. **Tier 0** green (locally + the `sniffers:harness` CI job).
2. **Tier 1** smoke: every skill/workflow/subagent behaves per the criteria above.
3. **Worktree smoke** (T2.4 + T2.5).
4. **Full `make tests` green** (T2.3) and equal to the `master` baseline.

If a Tier-1 item misbehaves, fix the offending `.claude/` file (not the gate) and re-run.
