# AGENTS.md

Read [CLAUDE.md](CLAUDE.md) first; it is the source of truth for this repository's Docker/Makefile workflow, docs, agent harness, and validation rules.

## Codex Environments

- **SDC** (`skilld-labs/skilld-docker-container`): use the `master` default branch; start with the lightweight harness/static gates before Docker-heavy review-app work.
- **druxxy** (`skilld-labs/druxxy`): use its `1.x` default branch; validate profile/core compatibility there before changing SDC's `PROFILE_NAME=druxxy` assumptions.

## Review Guidelines

Focus GitHub reviews on real P0/P1 risks: CI breakage, portability regressions, security issues, and docs/runtime drift.
