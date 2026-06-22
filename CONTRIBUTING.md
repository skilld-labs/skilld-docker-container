# Contributing

This repo is a **template** that downstream Drupal projects are seeded from, and it powers their GitLab
CI review apps. Changes here ripple outward, so favor small, well-tested, well-documented changes.

New to the codebase? Read [docs/architecture.md](docs/architecture.md) and
[docs/local-development.md](docs/local-development.md) first.

## Ground rules

- **Everything runs in containers.** Don't run `composer`/`drush`/`phpcs`/`yarn` on the host — use the
  Makefile wrappers (`make drush …`, `make phpcs`, `make exec`). See [CLAUDE.md](CLAUDE.md).
- **`docker/docker-compose.yml` is immutable.** Customize via `docker/docker-compose.override.yml` (generated
  from its `.default`). Same for `.env` ← `.env.default`. `make diff` shows your drift; never commit
  `.env` or the override (they're gitignored).
- **Composer manages code, not Drush.** `drush/policy.drush.inc` blocks `pm-download`/`pm-update`/
  `pm-updatecode`. Use `composer require` / `composer update`.
- **No committed patches.** `composer.json`'s `extra.patches` must reference upstream URLs
  (drupal.org / GitHub issues), never a local file — `make patchval` (and `test:patch` in CI) enforces
  this.
- **Custom code only in** `web/modules/custom/` and `web/themes/custom/`. Everything else under `web/`
  is Composer-installed and gitignored.

## Branching & commits

- Branch off `master` (the template ships as a rolling `master`; there are no semver releases).
- Keep one logical change per PR. Dependency bumps: one dependency per PR (see the
  [`dep-bump`](.claude/skills/dep-bump/SKILL.md) skill).
- NewRelic agent bumps follow the existing message convention — `NR: <release-notes-url>` (see
  `git log`).

## Quality gates (run before pushing)

```sh
make hooksymlink   # once: symlinks .git/hooks/pre-push → scripts/git_hooks/sniffers.sh
make sniffers      # clang + composer validate + phpcs + newlineeof  (what the pre-push hook runs)
make tests         # full suite: sniffers + cinsp + rector + upgrade_status + behat + watchdog + …
```

The pre-push hook runs `make sniffers` automatically; bypass once with `git push --no-verify` only when
you must. CI runs the same `make` targets — see [docs/ci-pipeline.md](docs/ci-pipeline.md), and mind the
`cinsp`-before-schema-mutators ordering constraint (#323).

If you change docs or the `.claude/` harness, also run the static gate (`make harnessval`, or the
`sniffers:harness` CI job) and follow [docs/testing.md](docs/testing.md) for the full pre-merge plan.

## Documentation

User-facing docs live in [`docs/`](docs/) and travel with the code. If you change CI, the install flow,
the app server, or the upgrade path, update the matching doc in the same PR. The
[`backlog-grooming`](.claude/skills/backlog-grooming/SKILL.md) skill keeps
[docs/backlog.md](docs/backlog.md) current.

## Agent harness

This repo ships a Claude Code harness under [`.claude/`](.claude/README.md) (skills, subagents,
workflows, permission allowlist) for the recurring maintenance jobs — Drupal upgrades, dependency/
NewRelic bumps, CI/review-app triage, backlog grooming, and observability.

- **Forks/seeds inherit it for free** (it's committed).
- **Existing projects adopt it** by copying `.claude/` once:
  ```sh
  cp -r path/to/skilld-docker-container/.claude ./
  ```
  then review `.claude/settings.json` (note `make:*` is allowed intentionally — `make` is the project's
  primary interface and includes `make clean`).
- Project context for agents lives in this repo's [`CLAUDE.md`](CLAUDE.md) and [`docs/`](docs/), **not**
  in any parent-directory `CLAUDE.md`.
- Heavy or parallel agent work should run in **git worktrees**
  ([docs/parallel-environments.md](docs/parallel-environments.md)) so multiple branches build at once
  without colliding.

## License

By contributing you agree your contributions are licensed under the repository's MIT license.
