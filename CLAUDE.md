# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A developer starterkit / Composer project template for **Drupal 10** sites (`skilld-labs/sdc`), run
entirely inside Docker Compose and driven by a **Makefile**. It is not a ready-to-run application —
it scaffolds a Drupal install (default profile `druxxy`), seeds demo content, and bundles a full
sniffer/test pipeline used both locally and in GitLab CI.

## Golden rule: everything runs in containers

You almost never invoke `php`, `composer`, `drush`, `yarn`, or `phpcs` directly on the host. The
Makefile wraps them so they execute inside the `php` service container as the host user:

- `php = docker compose exec -T --user $(CUID):$(CGID) php <cmd>` — run as the host user.
- `php-0 = docker compose exec -T --user 0:0 php <cmd>` — run as root (package installs, chmod).
- `frontexec` (in `front.mk`) runs yarn tasks in a separate throwaway `IMAGE_FRONT` node container,
  mounting only `web/themes/custom/$(THEME_NAME)`.

Containers must be up (`make all` or `make provision`) before most targets work. Run `make` with no
target for the auto-generated help (each `## comment` above a target becomes its help line).

The dummy rule `%: ; @:` lets trailing words be passed as arguments — that is how `make drush <cmd>`
and `make xdebug on` forward extra tokens to the wrapped command.

## Common commands

| Command | Purpose |
| --- | --- |
| `make all` | Full build from scratch: provision → back → front → si → localize → hooks → info |
| `make allfast` | Same, but DB lives in `/dev/shm` (RAM, non-persistent, faster) |
| `make clean` | Tear down containers/network and delete composer-installed code + DB data |
| `make si` | (Re)install the Drupal site |
| `make dev` | Enable devel/kint, Twig debug, disable caches & aggregation |
| `make exec` / `make exec0` | Open a shell in the php container (user / root) |
| `make drush <cmd>` | Run drush; pass flags after `--`, e.g. `make drush en devel -- -y` |
| `make phpcs` / `make phpcbf` | Check / autofix coding standards (custom code only) |
| `make front` / `make lint` / `make storybook` | Theme build / lint+fix / Storybook (need `THEME_NAME`) |
| `make tests` | Run the full validation + test suite (see below) |
| `make behat` | Run Behat browser tests |
| `make xdebug on\|off\|status` / `make blackfire` / `make newrelic` | Profiling/debug PHP extensions — `xdebug` toggles on/off/status; `blackfire` and `newrelic` enable only (`newrelic` needs `NEW_RELIC_LICENSE_KEY`) |

### Tests & validations

`make tests` chains: `sniffers` (`clang` config-langcode, `compval` composer validate, `phpcs`,
`newlineeof`) → `cinsp` (config schema) → `drupalrectorval` → `upgradestatusval` → `behat` →
`watchdogval` → `statusreportval` → `patchval`. Each is its own target in `scripts/makefile/tests.mk`
and can be run individually (e.g. `make phpcs`, `make cinsp`).

- **PHPCS** runs in a dedicated `skilldlabs/docker-phpcs-drupal` image against **only**
  `web/modules/custom` and `web/themes/custom`, using the `Drupal` + `DrupalPractice` standards.
- **Behat** (`make behat`): copies `behat.default.yml` → `behat.yml`, substitutes the live site URL,
  starts a headless Chromium driver container (`IMAGE_DRIVER`) sharing the php container's network on
  remote-debugging port 9222, then runs `vendor/bin/behat` (auto-`--rerun` on failure). Step
  definitions live in `features/bootstrap/FeatureContext.php` (extends `RawDrupalContext`); features
  in `features/*.feature`. To run a single feature, `make exec` then
  `vendor/bin/behat features/your.feature`.

## Architecture & layout

- **Makefile is modular**: the root `Makefile` does `include scripts/makefile/*.mk`. Add
  project-specific targets by dropping a new `scripts/makefile/<name>.mk` (see `backup.mk` as a model);
  do not bloat the root Makefile.
- **Config files are generated from `.default` templates** on first `make` run and must not be
  committed: `.env` ← `.env.default`, `docker/docker-compose.override.yml` ←
  `docker/docker-compose.override.yml.default`. `docker/docker-compose.yml` is the immutable base (a single
  `php` service + network); all customization (DB engine, mail, Traefik labels, extra services) goes
  in the override file. `make diff` shows how your local copies drift from the templates.
- **Drupal web root is `web/`.** Composer installs core/contrib/profiles/themes there
  (`installer-paths` in `composer.json`); all of that is gitignored. **Your code lives in
  `web/modules/custom/` and `web/themes/custom/` only** — those are the only tracked code paths and
  the only ones sniffed/tested.
- **App server is pluggable.** The php image (`IMAGE_PHP`, default `skilldlabs/php:83-unit`) can run
  under NGINX Unit (`docker/unit.json`), FrankenPHP/Caddy (`docker/Caddyfile`), or php-fpm.
  `scripts/makefile/reload.sh` detects the running SAPI (`/proc/1/comm`) and reloads it correctly —
  use `make reload` after changing server config, never assume a specific server.
- **Database** defaults to SQLite (`DB_URL` in `.env`). MySQL/PostgreSQL are opt-in by uncommenting
  the relevant service in the override file and changing `DB_URL`; `system-detection.mk` +
  `DB_MOUNT_DIR` logic in the Makefile handle persistent volume paths per engine.
- **Install modes** (`PROJECT_INSTALL` env): empty → install from the `PROFILE_NAME` profile;
  `config` → `drush si --existing-config` then `drush cim` (config-driven install from `config/sync`).
- **Content seeding** (`make content`): enables `default_content` (+ `project_default_content`) then
  `migrate_generator`, which builds migrations from CSVs in `content/`, imports them (tag `mgg`), then
  uninstalls the generator modules to leave a clean site.
- **Settings injection**: `make si` appends `settings/settings.local.php` (private files path, mail)
  into Drupal's `settings.php` and uncomments its include; `settings.redis.php` is appended only when
  Redis is enabled. `settings.dev.php` is for the dev profile.

## Conventions & gotchas

- **Use Composer, not Drush, for code management.** `drush/policy.drush.inc` blocks `pm-download`,
  `pm-update`, `pm-updatecode` — run `composer require` / `composer update` instead.
- `COMPOSE_PROJECT_NAME` is auto-sanitized to lowercase alphanumerics in `.env` on every make run;
  the default `projectname` triggers an interactive prompt during `provision`.
- A pre-push git hook (symlinked by `make hooksymlink` to `scripts/git_hooks/sniffers.sh`) runs the
  `sniffers` target. Bypass with `git push --no-verify`.
- No `composer.lock` is committed (intentional — avoids downstream merge conflicts);
  `ScriptHandler::checkComposerVersion` enforces a recent Composer.
- Front targets silently no-op unless `THEME_NAME` (in `.env`) points to a real
  `web/themes/custom/<name>` directory; CI front jobs need `THEME_PATH` set in `.gitlab-ci.yml`.
- GitLab CI (`.gitlab-ci.yml`) reuses these same make targets across stages
  (sniffers → prepare → build → update → tests), deploying review environments behind Traefik;
  keep CI behavior and Makefile targets in sync when changing either.

## Delivery / extras

`scripts/` also holds opt-in helpers, each with its own README: `delivery-{archive,docker,git}/`
(release packaging), `mirroring/` (repo mirroring), and `multisite/` (config_split-based site
switching). They are examples to copy into a real project's CI, not active by default. Indexed in
[docs/delivery-and-ops.md](docs/delivery-and-ops.md).

## Review apps & CI

This template's main job is spinning up **GitLab CI review apps** (ephemeral per-MR sites behind
Traefik) and running a large sniffer/test pipeline. `.gitlab-ci.yml` is itself a **parent-pipeline
template** included by downstream projects. Full narrative docs live in [`docs/`](docs/):

- [docs/review-apps.md](docs/review-apps.md) — review-app lifecycle, URLs, TTLs, teardown, required
  CI/CD variables. **Start here.**
- [docs/ci-pipeline.md](docs/ci-pipeline.md) — every job, the job → `make` target → script map, the
  validation gates, and the `cinsp`-before-schema-mutators ordering rule (#323).
- [docs/architecture.md](docs/architecture.md), [docs/local-development.md](docs/local-development.md),
  [docs/upgrading.md](docs/upgrading.md) (D10→11→12), [docs/observability.md](docs/observability.md),
  [docs/parallel-environments.md](docs/parallel-environments.md) (git-worktree parallel stacks).

## Working with agents here

A Claude Code harness lives in [`.claude/`](.claude/README.md) so this template — and projects seeded
from it — can be maintained by agents. Prefer these over ad-hoc work:

- **Skills** (`/<name>`): `drupal-upgrade`, `dep-bump` (NewRelic-first), `review-app-triage`,
  `backlog-grooming`, `observability-up`.
- **Subagents**: `upgrade-validator`, `ci-log-analyzer`, `dep-bumper`.
- **Workflows**: `drupal-upgrade.workflow.js`, `newrelic-bump.workflow.js`.

Skills wrap **existing `make` targets** — keep that contract. Run heavy/parallel agent work in git
worktrees ([docs/parallel-environments.md](docs/parallel-environments.md)). Contributor-facing rules
are in [CONTRIBUTING.md](CONTRIBUTING.md).
