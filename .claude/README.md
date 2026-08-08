# Agent harness

This directory makes the template **agent-manageable** with Claude Code. It ships skills, subagents,
workflows, and a permission allowlist for the recurring maintenance jobs this project needs.

Because the template is consumed as a **rolling master** (forks/seeds track branches, not releases),
keeping the harness *in the repo* means projects seeded from it **inherit agent-driven management for
free**. Existing projects copy `.claude/` once (see
[CONTRIBUTING.md → Agent harness](../CONTRIBUTING.md#agent-harness)).

## Contents

| Path | What |
| --- | --- |
| [`settings.json`](settings.json) | Allowlist for the read-mostly `make` / `docker` / `git` / `gh` / `composer validate` calls these jobs use, to cut permission prompts. **`make:*` is allowed intentionally** — `make` is this project's primary interface (it includes `make clean`, so review destructive runs). |
| `skills/` | User-invokable runbooks (`/<name>`) wrapping existing `make` targets |
| `agents/` | Subagent definitions used by the skills/workflows |
| `workflows/` | Deterministic multi-step Workflow scripts for the heavy jobs |

## Skills (`/<name>`)

- [`review-app-triage`](skills/review-app-triage/SKILL.md) — read pipeline + Behat/Lighthouse/watchdog
  output and localize failures.
- [`drupal-upgrade`](skills/drupal-upgrade/SKILL.md) — execute the
  [upgrade runbook](../docs/upgrading.md) (D10 → 11 → 12).
- [`dep-bump`](skills/dep-bump/SKILL.md) — bump a dependency; NewRelic agent is the first-class case.
- [`backlog-grooming`](skills/backlog-grooming/SKILL.md) — triage open PRs/issues, regenerate
  [docs/backlog.md](../docs/backlog.md).
- [`observability-up`](skills/observability-up/SKILL.md) — bring the logs/traces stack up and print the
  Grafana URL.

## Agents

- [`upgrade-validator`](agents/upgrade-validator.md) — runs `upgradestatusval` + `drupalrectorval`,
  reports blockers (read/much-analysis).
- [`ci-log-analyzer`](agents/ci-log-analyzer.md) — read-only triage of CI / container logs.
- [`dep-bumper`](agents/dep-bumper.md) — edits a single dependency pin and validates.

## Workflows

Run via the Workflow tool (or `/workflows`). Opt-in — they only run when invoked.

- [`drupal-upgrade.workflow.js`](workflows/drupal-upgrade.workflow.js) — bump → remove dropped modules
  → rector → `upgrade_status` → iterate, in an isolated worktree.
- [`newrelic-bump.workflow.js`](workflows/newrelic-bump.workflow.js) — bump the pinned NewRelic agent
  version and validate.

## Conventions

- Project context lives in this repo's [`CLAUDE.md`](../CLAUDE.md) and [`docs/`](../docs/). The
  parent-directory `CLAUDE.md` (a "Plasma" doc) is **unrelated** — don't rely on it here.
- Skills wrap **existing `make` targets** rather than reimplementing logic; keep that contract so the
  harness stays correct as the Makefile evolves.
- Heavy/parallel jobs run in **git worktrees** (see [parallel-environments.md](../docs/parallel-environments.md))
  so multiple branches can build at once without colliding.
