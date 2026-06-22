# Upgrade runbook: Drupal 10 → 11 → 12

This is the human-readable twin of the `drupal-upgrade` agent workflow
([`.claude/workflows/drupal-upgrade.workflow.js`](../.claude/workflows/drupal-upgrade.workflow.js)).
The strategy is **transitional**: move the template to `^10.3 || ^11` so downstream projects keep
working on D10.3 while D11 becomes possible, then stage D12 separately.

The verification harness already exists — `make upgradestatusval`, `make drupalrectorval`,
`make cinsp`, and the full `make tests` — so "green" is well defined. See
[ci-pipeline.md](ci-pipeline.md#what-the-validation-gates-actually-assert).

## ⚠️ Gating dependency: druxxy

The default install profile is `skilldlabs/druxxy` (external package). **As of this writing, the
latest release `v1.5.1` requires `drupal/core-recommended: ^10.6` — no published druxxy version
supports Drupal 11.** A D11 build is **blocked** until a druxxy major that allows `^11` exists.

Two paths:
1. **Preferred** — publish/obtain a druxxy major with `drupal/core-recommended: ^10.6 || ^11`, then
   proceed below.
2. **Unblock for testing** — temporarily switch `PROFILE_NAME` to a core profile (`standard`/`minimal`)
   on a throwaway branch to validate the rest of the upgrade independently of druxxy.

Re-check druxxy before starting: `composer show skilldlabs/druxxy --all` (or Packagist).

## Step 1 — Core constraints (transitional)

In [`composer.json`](../composer.json):

```diff
- "drupal/core-composer-scaffold": "^10.3.1",
- "drupal/core-vendor-hardening": "^10.3.1",
+ "drupal/core-composer-scaffold": "^10.3.1 || ^11",
+ "drupal/core-vendor-hardening": "^10.3.1 || ^11",
```

Bump `skilldlabs/druxxy` to its D11-capable major once available (currently pinned `^1.1`; note even
within D10, `^1.5` exists and tracks `^10.6`).

## Step 2 — Remove modules dropped from D11 core

These three were added together for the D10 lock (commit `71f6aba`) and are **removed from Drupal 11
core**:

| Remove from `composer.json` | Replacement on D11 |
| --- | --- |
| `drupal/ckeditor` (CKEditor 4) | Core **CKEditor 5** (in core; no module needed) |
| `drupal/color` | None in core — drop unless a contrib successor is genuinely needed |
| `drupal/seven` (admin theme) | Core **Claro** admin theme |

After removing, grep the repo for references before assuming they are unused:

```sh
git grep -nE 'ckeditor|\bcolor\b|seven' -- web/ config* settings* .env.default Makefile scripts/
```

Check the `druxxy` profile and any `MODULES`/install code (`.env.default`, `Makefile` `si`/`content`)
for an enabled `seven`/`color`/`ckeditor` dependency, and switch the admin theme to `claro`.

## Step 3 — Update tooling

- **drupal-rector** — current pin `^0.20.3` is old. Bump to the latest (`^0.21` or the `1.0.x` line,
  which targets Rector 2.x) and add the Drupal 11 set to [`rector.php`](../rector.php) **if** that
  release exposes a `Drupal11SetList`:

  ```php
  $sets = [
    Drupal8SetList::DRUPAL_8,
    Drupal9SetList::DRUPAL_9,
    Drupal10SetList::DRUPAL_10,
  ];
  // Add the D11 set only if the installed drupal-rector release defines it —
  // referencing a missing class would fatal.
  if (class_exists(\DrupalRector\Set\Drupal11SetList::class)) {
    $sets[] = \DrupalRector\Set\Drupal11SetList::DRUPAL_11;
  }
  $rectorConfig->sets($sets);
  ```

  If no D11 set ships yet, rely on `upgrade_status` (Step 5) as the authority and keep rector at D10.
- **drush** — already `^13.2`, which supports D11. No change.
- **Other contrib** — `composer why-not drupal/core 11` to surface blockers (e.g. `default_content`,
  `migrate_generator`, `imagemagick`); bump each to its D11-compatible release.

## Step 4 — Re-verify the patch

[`composer.json`](../composer.json) carries one patch on `drupal/default_content` ("Do not reimport
existing entities"). Confirm it still applies on the D11-compatible release; **drop it if upstreamed**
(`test:patch` only forbids *committed* patch files, not remote URLs, but a stale patch will fail to
apply and break `composer install`).

## Step 5 — Resolve and validate

On a throwaway branch (the agent does this in an isolated worktree):

```sh
composer update --with-all-dependencies
make upgradestatusval   # drush upgrade_status:analyze — must report no FILE: lines
make drupalrectorval    # rector dry-run over custom code
make cinsp              # config schema (run before schema-mutating checks)
make tests              # full suite
```

Iterate on the `upgrade_status` report until clean. `upgrade_status` is the authority for "is this D11
ready"; rector helps auto-rewrite deprecated API calls in custom code.

## Step 6 — Prove it end-to-end

The real acceptance test is a **green review app on the D11 branch** — open an MR and run
`build:review`, then the `test:*` jobs (see [review-apps.md](review-apps.md)). A passing pipeline is
the definition of done for the transitional step.

## Step 7 — Drupal 12 readiness (staged, follow-up)

Do **not** fold D12 into the transitional branch. When D12-compatible druxxy/contrib exist:

- Switch the PHP image to **8.4** — images already exist: `skilldlabs/php:84-unit` (and
  `84-frankenphp`, `84-fpm`). Update `IMAGE_PHP` in `.env.default` and the `IMAGE_PHP` CI default.
- Move core constraints to include `^12`, add the D12 rector set if available, re-run Steps 5–6.
- Revisit `minimum-stability` (currently `dev`) only when pinning for a release.

## Quick checklist

- [ ] druxxy D11-capable release available (or profile temporarily swapped)
- [ ] core constraints → `^10.3.1 || ^11`
- [ ] removed `ckeditor` / `color` / `seven`; admin theme → claro; CKEditor 5 verified
- [ ] rector bumped (+ D11 set if present); drush `^13.2`
- [ ] contrib bumped (`composer why-not drupal/core 11` clean)
- [ ] `default_content` patch re-verified or dropped
- [ ] `make upgradestatusval` / `drupalrectorval` / `cinsp` / `tests` green
- [ ] D11 review app builds green
- [ ] D12: PHP 8.4 image + `^12` constraints tracked as a follow-up
