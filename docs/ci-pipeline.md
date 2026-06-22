# CI pipeline reference

This is a job-by-job reference for [`.gitlab-ci.yml`](../.gitlab-ci.yml). For *how review apps work*
(URLs, TTLs, teardown), read [review-apps.md](review-apps.md) first.

Every job runs on a **shell runner** (it shells out to `docker` / `docker compose` / `make`), selected
by the `.runner_tag_selection` tag anchor. The base image is `$IMAGE_PHP` (CI default
`skilldlabs/php:83`). The shared `before_script` just prints diagnostics (`date`, `id`, `env`, …).

## Stages

```
sniffers → prepare → build → update → tests → more tests
```

- **sniffers** — static checks on the changed code; no running site needed.
- **prepare** — build backend (composer) and frontend (yarn) artifacts, cached and passed forward.
- **build** — deploy the review app (see [review-apps.md](review-apps.md)).
- **update** — optional: simulate a production update against the last tag's DB/files.
- **tests / more tests** — functional and quality gates run against the deployed review app.

## Job → `make` target → script map

| Job | Stage | Runs | Underlying script / definition |
| --- | --- | --- | --- |
| `sniffers:clang` | sniffers | `make clang` | `scripts/makefile/baseconfig-langcode.sh` (base-config langcode) |
| `sniffers:compose` | sniffers | `composer validate --profile` | composer built-in |
| `sniffers:front` | sniffers | `make front-install` + `make lintval` | `scripts/makefile/front.mk` (yarn lint) — only if `$THEME_PATH` |
| `sniffers:phpcs` | sniffers | `make phpcs` | `scripts/makefile/tests.mk` → `skilldlabs/docker-phpcs-drupal` (Drupal+DrupalPractice, custom code only) |
| `sniffers:newlineeof` | sniffers | `make newlineeof` | `scripts/makefile/newlineeof.sh` |
| `sniffers:harness` | sniffers | `node scripts/ci/validate-harness.mjs` | docs + `.claude/` static gate (see [testing.md](testing.md)) |
| `prepare:back` | prepare | `composer install … create-required-files` | inline docker run; caches `vendor/`, `web/core`, contrib, drush |
| `prepare:front` | prepare | `make front-install` + `make front-build` | `scripts/makefile/front.mk` (yarn build → theme `dist/`) |
| `build:review/master/tag` | build | `make all_ci` | `Makefile:61` (provision → si → localize → hooksymlink → info) |
| `stop_review` | build | `make clean` | `Makefile` (drop stack + build dir) |
| `generate:logins` | build | `make info` | `Makefile` (login links + IPs) |
| `test:deploy` | update | `make drush deploy` vs last tag | inline; needs `TEST_UPDATE_DEPLOYMENTS=TRUE` + API token |
| `test:storybook` | tests | `make build-storybook` | `scripts/makefile/front.mk` — only if `$STORYBOOK_PATH` |
| `test:behat` | tests | `make behat` | `scripts/makefile/tests.mk` (Behat + headless Chromium; junit report) |
| `test:cinsp` | tests | `make cinsp` | `scripts/makefile/config-inspector-validation.sh` |
| `test:drupalrector` | tests | `make drupalrectorval` | `scripts/makefile/tests.mk` + `rector.php` (dry-run) |
| `test:lighthouse` | tests | `lhci collect/assert` | `lighthouserc.yml`; runs in `cypress/browsers` container |
| `test:contentgen` | tests | `make contentgen` | `scripts/makefile/contentgen.sh` — `when: manual` |
| `test:patch` | tests | `make patchval` | `scripts/makefile/patchval.sh` — skip with `RUN_PATCHVAL_CI_JOB=FALSE` |
| `test:statusreport` | more tests | `make statusreportval` | `scripts/makefile/status-report-validation.sh` |
| `test:upgradestatus` | more tests | `make upgradestatusval` | `scripts/makefile/upgrade-status-validation.sh` |
| `test:watchdog` | more tests | `make watchdogval` | `scripts/makefile/watchdog-validation.sh` |

## What the validation gates actually assert

These are the same targets `make tests` runs locally, so a green pipeline is reproducible on a laptop.

- **`cinsp`** — enables `config_inspector`, fails if `drush config:inspect --only-error` reports any
  schema error. **Ordering matters (see below).**
- **`drupalrector`** — `vendor/bin/rector process --dry-run` over `web/modules/custom` +
  `web/themes/custom`, using the set lists in [`rector.php`](../rector.php) (currently Drupal 8/9/10).
- **`upgradestatus`** — enables `upgrade_status`, fails if
  `drush upgrade_status:analyze --all --ignore-contrib --ignore-uninstalled` prints any `FILE:` line.
- **`statusreport`** — fails on any severity-2 (error) row in `/admin/reports/status`, except the
  ignored `Trusted Host Settings`.
- **`watchdog`** — fails if any `Emergency|Alert|Critical|Error` log was written during the run.
- **`patch`** — fails if `composer.json`'s `extra.patches` contains a **non-remote** (committed) patch
  file; patches must be hosted upstream (drupal.org/GitHub issue URLs).
- **`behat`** — copies `behat.default.yml` → `behat.yml`, injects the review URL, boots a headless
  Chromium driver container, runs `vendor/bin/behat`, and emits a JUnit report consumed by GitLab.

### Test-ordering constraint (issue #323)

`test:cinsp` is intentionally meant to run **before** the jobs that toggle modules
(`test:upgradestatus` enables then uninstalls `upgrade_status`; `test:cinsp` enables `config_inspector`).
Config schema must be collected while the dev/inspection modules' schema is still present in the
container. When customizing stage/job order in a downstream project, **keep `cinsp` ahead of the
schema-mutating jobs** or you will get spurious schema errors.

## Artifacts & reports

- `prepare:back` → `vendor/`, `web/`, `drush/` (1 day); `prepare:front` → theme `dist/` + `node_modules/`.
- `build:tag` → `web/sites/*/files/` + `.cache` (the DB) for 1 week — the input to `test:deploy`.
- `test:behat` → `junit/*.xml` (surfaced as GitLab **JUnit test report**) + screenshots under
  `web/screenshots/` on the review URL.
- `test:lighthouse` → HTML reports moved to `web/lighthouseci/`, linked from the job log.

## Update-path simulation (`test:deploy`)

Opt-in via `TEST_UPDATE_DEPLOYMENTS=TRUE`. It calls the GitLab API to find the **last tag**, downloads
that tag's `build:tag` artifact (production-like DB + files), swaps them into the running review app,
disables `config_ignore` if present, and runs `drush deploy` — i.e. it rehearses what deploying the MR
on top of the current release would do. Requires `GITLAB_PROJECT_ACCESS_TOKEN` (and
`GITLAB_PROJECT_BASIC_AUTH` if the repo is behind basic auth).

## Opportunities (tracked in the backlog)

- **GitLab Code Quality reports** (issue #295) — emit `artifacts:reports:codequality` from
  `sniffers:phpcs`/`test:drupalrector` so findings annotate the MR diff inline.
- **Dynamic environment URL via dotenv** (issue #287) — have the deploy job write the review URL to a
  `artifacts:reports:dotenv` file so downstream jobs reuse it instead of recomputing it.

See [backlog.md](backlog.md) for the full triage.
