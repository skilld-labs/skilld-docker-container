# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A developer starterkit (project template) for Drupal 10 projects, orchestrated entirely
through Docker Compose and a `make`-driven workflow. There is no PHP/Node toolchain on the
host: every command (composer, drush, phpcs, yarn, behat) runs inside containers. The
`Makefile` is the single entry point — reading it (and the included `scripts/makefile/*.mk`)
is the fastest way to understand any task.

## Commands

All commands are `make` targets. Run `make` (or `make help`) to list them with descriptions
(help text is the `## comment` line directly above each target).

- `make all` — Full install from scratch: provision containers → composer install (`back`) →
  build theme (`front`) → install Drupal (`si`) → import translations (`localize`) → install
  git hooks → print URLs/logins.
- `make allfast` — same as `all` but puts the SQLite DB in `/dev/shm` (RAM, non-persistent).
- `make clean` — remove build artifacts, containers, network, scaffold files, DB data.
- `make si` — (re)install the Drupal site only.
- `make exec` / `make exec0` — shell into the php container as your user / as root.
- `make drush <cmd>` — run drush; pass flags after a double dash: `make drush cr -- -y`.
- `make dev` — enable dev mode (devel/kint, Twig debug, disable caches & aggregation).
- `make info` — print container IPs and one-time login links for admin & tester users.
- `make diff` — show how local `.env` / `docker-compose.override.yml` differ from defaults.

### Lint / sniffers / tests

- `make phpcs` — Drupal + DrupalPractice coding-standards check over `web/{modules,themes}/custom`.
- `make phpcbf` — auto-fix coding-standards violations.
- `make sniffers` — `clang` + `compval` + `phpcs` + `newlineeof`. This is what the **pre-push
  git hook** runs (`scripts/git_hooks/sniffers.sh`); bypass with `git push --no-verify`.
- `make tests` — full suite: `sniffers cinsp drupalrectorval upgradestatusval behat watchdogval
  statusreportval patchval`.
- `make behat` — Behat scenarios from `features/` against the running site; auto-starts/stops a
  headless chromium driver container. Pass args via `BEHAT_ARGS`.
- `make front` / `make lint` / `make storybook` — theme build / linters / Storybook (only run if
  `THEME_NAME` points to an existing dir under `web/themes/custom`).

To run a single Behat scenario, exec into the container and call behat directly, e.g.
`make exec` then `vendor/bin/behat features/generic_tests.feature:12`.

## Architecture

### Configuration & overrides
- `.env` is generated from `.env.default` on first `make` run (and `docker-compose.override.yml`
  from its `.default`). **Never edit `docker-compose.yml`** — it holds the base requirements;
  put local changes in the override file. `make` warns (`make diff`) when local files drift
  from defaults. `COMPOSE_PROJECT_NAME` must be customized before install.
- `make` injects host UID/GID (`CUID`/`CGID`) into container exec calls so files written in
  containers stay owned by the host user. The two core helpers in the Makefile are
  `php = docker compose exec --user $(CUID):$(CGID) php` and `php-0 = ... --user 0:0 php`.

### Containers (`docker/docker-compose.yml`)
- `php` is the only service enabled by default (container name `${PROJECT}_web`); it serves
  the site. nginx, apache, solr, redis, mysql, postgresql are present but commented out —
  enable them in the override file. The default `IMAGE_PHP` (`skilldlabs/php:83-unit`) runs
  Nginx Unit; `reload.sh` detects the SAPI (unit / frankenphp / php-fpm) and reloads
  accordingly, so the same target works across web-server images.

### Database
- Defaults to SQLite (`DB_URL` in `.env`). Switch to MySQL/PostgreSQL by enabling the service
  in the override file and changing `DB_URL`. The Makefile computes `DB_MOUNT_DIR` based on
  which DB service is present in the compose config.

### Drupal site install (`si` target)
Two install modes, selected by `PROJECT_INSTALL`:
- `config` → `drush si --existing-config` then `drush cim` (install from exported config).
- anything else → `drush si $(PROFILE_NAME)` (fresh install from profile, default `druxxy`).
After install it creates a `tester` user with the `contributor` role for Behat/manual testing.

### Content seeding (`content` target)
Content is generated, not committed as fixtures: CSV files in `content/` are turned into Drupal
migrations by `migrate_generator`, imported (`--tag=mgg`), then the generator/migration modules
are uninstalled. `project_default_content` (in `web/modules/custom`) provides default content
via the `default_content` module and is likewise enabled-then-uninstalled.

### Code layout
- `web/` — Drupal docroot. Contrib code (`core`, `modules/contrib`, `themes/contrib`,
  `profiles/contrib`, `libraries`, `vendor`) is composer-managed and gitignored; only
  `web/modules/custom` and `web/themes/custom` hold project code.
- `composer.json` — installer-paths route packages into `web/`; `drupal-cleanup` strips tests
  from contrib; `drupal-scaffold` web-root is `web/`. Patches go through `cweagans/composer-patches`
  (`patchval` enforces that patches come from approved sources).
- `settings/` — `settings.local.php`, `settings.dev.php`, `settings.redis.php` are copied into
  `web/sites/default/` by the relevant make targets rather than committed there.
- `scripts/makefile/*.mk` — make targets are split by concern (`tests.mk`, `front.mk`,
  `backup.mk`, `help.mk`, `system-detection.mk`) and all included by the root `Makefile`. Add
  project-specific targets as a new `scripts/makefile/<name>.mk`.
- `scripts/{delivery-*,mirroring,multisite}/` — opt-in GitLab CI snippets and shell scripts for
  delivery/mirroring/multisite workflows (each has its own README).
- `features/` — Behat features + `bootstrap/FeatureContext.php`.
- `translations/` — `.po` files imported by `make localize` (plus online locale updates).

### CI
`.gitlab-ci.yml` drives CI (stages: sniffers → prepare → build → update → tests → more tests),
calling the same `make` targets used locally. Front/storybook jobs are gated on `THEME_PATH` /
`STORYBOOK_PATH` variables being set. There is no GitHub Actions workflow.
