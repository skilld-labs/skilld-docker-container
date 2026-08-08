---
name: drupal-upgrade
description: Move the template toward Drupal 11 (transitional ^10.3 || ^11) or stage Drupal 12. Bumps core constraints, removes modules dropped from core, updates rector, and iterates to a clean upgrade_status. Use for "upgrade to Drupal 11", "D11 compatibility", "prepare D12".
---

# Drupal upgrade

Execute the runbook in [docs/upgrading.md](../../../docs/upgrading.md). This skill is the interactive
entry point; for an unattended, isolated run use the
[`drupal-upgrade` workflow](../../workflows/drupal-upgrade.workflow.js).

## Before you start — check the gate
The default profile `skilldlabs/druxxy` gates D11. Verify first:

```sh
composer show skilldlabs/druxxy --all   # is there a release allowing drupal/core ^11?
```

As of the last check, the newest druxxy (`v1.5.1`) only allows `^10.6` — **no D11 yet**. If still
blocked, either obtain a D11-capable druxxy major or temporarily set `PROFILE_NAME=standard` on a
throwaway branch to validate the rest.

## Steps (transitional D11)

1. Create/checkout a throwaway branch (ideally an isolated worktree —
   [parallel-environments.md](../../../docs/parallel-environments.md)).
2. `composer.json`: core scaffold/hardening → `^10.3.1 || ^11`; bump druxxy when available.
3. Remove `drupal/ckeditor`, `drupal/color`, `drupal/seven` (dropped from D11 core). Switch the admin
   theme to **claro**, rely on core **CKEditor 5**. `git grep` for stragglers first.
4. Bump `palantirnet/drupal-rector` (current `^0.20.3` is old → `^0.21`/`1.0.x`); add `Drupal11SetList`
   to `rector.php` **only if** the installed release ships it.
5. Re-verify or drop the `drupal/default_content` patch in `composer.json`.
6. `composer update --with-all-dependencies`, then run the gates and iterate:
   `make upgradestatusval` (authority) → `make drupalrectorval` → `make cinsp` → `make tests`.
   Delegate the run/parse loop to the [`upgrade-validator`](../../agents/upgrade-validator.md) subagent.
7. Open an MR; the definition of done is a **green D11 review app**.

## D12 (staged, separate branch)
Switch `IMAGE_PHP` to a PHP 8.4 image (`skilldlabs/php:84-unit` exists), widen constraints to include
`^12`, add the D12 rector set if present, re-run the gates. Don't fold D12 into the D11 branch.

## Guardrails
- Never bypass `upgrade_status`/rector to "make it green" — fix the deprecations.
- Keep the change transitional (`|| ^11`) so downstream D10.3 projects keep resolving.
