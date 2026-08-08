---
name: dep-bump
description: Bump a dependency and validate it. First-class case is the recurring NewRelic PHP agent version bump; also handles composer packages and Docker image tags. Use for "bump NewRelic", "update dependency X", "upgrade the php image".
---

# Dependency bump

Small, validated version bumps — the steady-state maintenance this template needs most (NewRelic
agent bumps dominate its git history).

## NewRelic agent (first-class)

The pinned version lives in [`scripts/makefile/newrelic.sh`](../../../scripts/makefile/newrelic.sh).

1. Find the latest agent release (NewRelic PHP agent release notes / download index).
2. Update the version string in `scripts/makefile/newrelic.sh` (and any matching version in
   `.env.default` / docker config if present).
3. Validate: `composer validate`, and if a stack is up, `make newrelic reload` then confirm the agent
   loads (`make drush -- php-eval "var_dump(extension_loaded('newrelic'));"` or check
   `docker compose logs php`).
4. Commit with the release tag in the message (matches the repo's existing
   `NR: <url>` convention — see `git log`).

For an unattended run use the [`newrelic-bump` workflow](../../workflows/newrelic-bump.workflow.js).

## Composer package

1. `composer why-not <pkg> <target-version>` to see blockers.
2. Edit the constraint in `composer.json`; `composer update <pkg> --with-dependencies`.
3. `composer validate` + `make tests` (or at least `make cinsp upgradestatusval`).
4. If it's a Drupal contrib bump for D11, route through [`drupal-upgrade`](../drupal-upgrade/SKILL.md).

## Docker PHP image

`IMAGE_PHP` in `.env.default` (and the CI default in `.gitlab-ci.yml`). Confirm the tag exists
(`skilldlabs/php` tags), bump, `make provision reload`, smoke-test the site.

## Guardrails
- One dependency per change; keep the diff reviewable.
- Never commit a local patch file (`test:patch` forbids it) — patches go to upstream URLs in
  `composer.json`'s `extra.patches`.
- Delegate the mechanical edit+validate to the [`dep-bumper`](../../agents/dep-bumper.md) subagent when
  doing several.
