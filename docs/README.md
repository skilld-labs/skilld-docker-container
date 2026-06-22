# Documentation

Narrative documentation for the Skilld Docker Container — a Composer + Makefile + Docker template for
Drupal projects, used to spin up **GitLab CI review apps** and run a full sniffer/test pipeline.

Start with the root [README.md](../README.md) for quickstart, then dive in here:

## Operating the template

- **[review-apps.md](review-apps.md)** — how ephemeral per-MR environments are built, addressed
  (Traefik URLs), and torn down; the required GitLab CI/CD variables. **Start here.**
- **[ci-pipeline.md](ci-pipeline.md)** — every CI stage and job, the job → `make` target → script
  map, the validation gates, and the `cinsp` ordering constraint.
- **[architecture.md](architecture.md)** — container topology, the pluggable app server (Unit /
  FrankenPHP / fpm), database engines, install flow, and the modular Makefile.
- **[local-development.md](local-development.md)** — running the stack on your machine, including
  macOS specifics.
- **[parallel-environments.md](parallel-environments.md)** — run several review-app-like stacks at
  once locally with `git worktree`; the basis for parallel agent runs.
- **[delivery-and-ops.md](delivery-and-ops.md)** — index of the opt-in delivery, mirroring, and
  multisite helpers under `scripts/`.
- **[observability.md](observability.md)** — getting logs and traces out of Docker (logs tier +
  opt-in OpenTelemetry traces).

## Maintaining the template

- **[upgrading.md](upgrading.md)** — the Drupal 10 → 11 → 12 upgrade runbook.
- **[testing.md](testing.md)** — how to validate the project + harness before merge (static gate,
  harness smoke, Docker functional) and the merge gate.
- **[backlog.md](backlog.md)** — triaged open PRs and issues (adopt / rebase / fold-into-docs /
  close-as-stale).
- **[../CONTRIBUTING.md](../CONTRIBUTING.md)** — branching, quality gates, conventions, and how
  downstream projects inherit the agent harness.

## Agent-managed maintenance

This repo ships a Claude Code harness under [`.claude/`](../.claude) so the template — and projects
seeded from it — can be maintained by agents (Drupal upgrades, dependency/NewRelic bumps, CI/review-app
triage, backlog grooming, observability). See [CONTRIBUTING.md](../CONTRIBUTING.md#agent-harness) and
[`.claude/README.md`](../.claude/README.md).
