# Architecture

This template assembles a Drupal 10 site with Composer and runs it in Docker, orchestrated by a
Makefile. This document covers the moving parts you need to understand before changing anything. For
day-to-day commands see the root [README.md](../README.md) and [CLAUDE.md](../CLAUDE.md).

## Container topology

The committed base, [`docker/docker-compose.yml`](../docker/docker-compose.yml), defines a **single
`php` service** (container `${COMPOSE_PROJECT_NAME}_web`) on a `front` bridge network, with the repo
mounted at `/var/www/html`. Everything else (databases, mail, alternate web servers, profiling,
observability) is opt-in and lives in
[`docker/docker-compose.override.yml.default`](../docker/docker-compose.override.yml.default), copied
to `docker/docker-compose.override.yml` on first run.

> **Rule:** `docker-compose.yml` is the immutable base — never edit it. Customize via the override
> file. `make diff` shows how your local `.env` / override drift from the `.default` templates.

Two Make helpers wrap container execution:

- `php = docker compose --env-file .env exec -T --user $(CUID):$(CGID) php …` (as the host user)
- `php-0 = … --user 0:0 …` (as root, for package installs / chmod)

## Pluggable app server (one image, three SAPIs)

The `php` image (`IMAGE_PHP`, default `skilldlabs/php:83-unit`) can serve Drupal under three runtimes,
abstracted by [`scripts/makefile/reload.sh`](../scripts/makefile/reload.sh), which detects the running
SAPI from `/proc/1/comm` and reloads it correctly:

| SAPI | Image tag | Config | Reload |
| --- | --- | --- | --- |
| **Nginx Unit** (default) | `:83-unit` | [`docker/unit.json`](../docker/unit.json) | `PUT` config to the Unit control socket |
| **FrankenPHP / Caddy** | `:83-frankenphp` | [`docker/Caddyfile`](../docker/Caddyfile) | `frankenphp reload` |
| **php-fpm** (legacy) | — | — | `kill -USR2 1` |

Use `make reload` after changing server config; never assume a specific server. **Nginx Unit is the
current default** — FrankenPHP image builds are problematic on arm64 (QEMU), which is why the default
was reverted to Unit (issue #467). Both `unit.json` and the `Caddyfile` implement the same Drupal
hardening (deny `*.php` outside `index.php`, block dotfiles/backups, long-cache static assets, gzip).

## Web root and code layout

The Drupal web root is `web/`. Composer's `installer-paths` (in [`composer.json`](../composer.json))
place core/contrib/profiles/themes under `web/{core,modules/contrib,profiles/contrib,themes/contrib}`,
and **all of that is gitignored**. The only tracked, sniffed, and tested code lives in:

- `web/modules/custom/` — custom modules (e.g. `project_default_content`)
- `web/themes/custom/` — the project theme (built separately in a node container, see `front.mk`)

## Database engines

`DB_URL` in `.env` selects the engine; SQLite is the default (no extra container):

| Engine | `DB_URL` | Persistence |
| --- | --- | --- |
| SQLite (default) | `sqlite://./../.cache/db.sqlite` | File under `.cache/` (or `/dev/shm` with `make fast`, non-persistent) |
| MySQL | `mysql://db:db@mysql/db` | Uncomment the `mysql` service in the override; volume under `DB_DATA_DIR` |
| PostgreSQL | `pgsql://db:dbroot@postgresql/db` | Uncomment `postgresql` + `load-extension.sh` (pg_trgm) |

The Makefile derives `DB_MOUNT_DIR` per engine and per project (`COMPOSE_PROJECT_NAME` + `CURDIR`), so
distinct projects/worktrees never collide on DB storage — the basis for
[parallel environments](parallel-environments.md).

## Install flow

`make all` chains: `provision → back → front → si → localize → hooksymlink → info`. In CI,
`make all_ci` skips `back`/`front` (prebuilt as artifacts). Key steps:

- **provision** — sanitize `COMPOSE_PROJECT_NAME`, bring up containers, install any
  `ADDITIONAL_PHP_PACKAGES`, enable NewRelic if `NEW_RELIC_LICENSE_KEY` is set, `make reload`.
- **si** (`PROJECT_INSTALL` env):
  - empty → `drush si $(PROFILE_NAME)` (default profile `druxxy`) with site name/mail/locale.
  - `config` → `drush si --existing-config` then `drush cim` (config-driven install).
  - Then `make content`, and creates a `tester` user with the `contributor` role.
- **content** — enables `default_content` + `project_default_content`, then `migrate_generator`, which
  builds migrations from the CSVs in [`content/`](../content/) (tag `mgg`), imports them, and uninstalls
  the generator modules to leave a clean site.
- **localize** — `drush locale:check/update` + import custom `translations/*.po`.
- **settings injection** — `make si` copies `settings/settings.local.php` into Drupal's `settings.php`
  (private files path, mail) and uncomments its include; `settings/settings.redis.php` is appended only
  when Redis is enabled.

## Modular Makefile

The root `Makefile` does `include scripts/makefile/*.mk`. Add project-specific targets by dropping a
new `scripts/makefile/<name>.mk` (see `backup.mk` as a template); do not bloat the root Makefile. The
extra word after a target is forwarded as an argument (the `%: ; @:` rule), which is how
`make drush <cmd>` and `make xdebug on` work.

## Health checks (opt-in)

There is no committed `healthcheck:` today (issue #152). Nginx Unit can expose a status/health route,
making a lightweight liveness probe cheap to add in the override file for the `php` service. This pairs
with [observability.md](observability.md).

## See also

- [review-apps.md](review-apps.md) / [ci-pipeline.md](ci-pipeline.md) — how this stack is deployed in CI.
- [local-development.md](local-development.md) — running it on your machine (incl. macOS).
- [upgrading.md](upgrading.md) — moving the stack to Drupal 11 / 12.
