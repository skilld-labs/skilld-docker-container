# Local development

Quickstart lives in the root [README.md](../README.md); this page covers the things that bite people:
the `.default` template convention, day-to-day commands, and macOS specifics (issue #400).

## First run

```sh
cp .env.default .env                                              # auto-created on first `make` too
cp docker/docker-compose.override.yml.default docker/docker-compose.override.yml
# set COMPOSE_PROJECT_NAME (or you'll be prompted), THEME_NAME if you have a theme
make all
```

`make all` builds everything and prints (`make info`) the site URL plus one-click admin/tester logins.

> **Config files are generated, not committed.** `.env` ← `.env.default` and
> `docker/docker-compose.override.yml` ← its `.default`. The committed `docker/docker-compose.yml` is
> the immutable base — never edit it. `make diff` shows your drift from both templates.

## Everyday commands

| Command | Purpose |
| --- | --- |
| `make all` / `make allfast` | Full build (allfast = DB in `/dev/shm`, faster, non-persistent) |
| `make si` | Reinstall the site |
| `make dev` | Devel + kint, Twig debug, caches/aggregation off |
| `make exec` / `make exec0` | Shell into the php container (user / root) |
| `make drush <cmd>` | Run drush; flags after `--`, e.g. `make drush cr`, `make drush en devel -- -y` |
| `make phpcs` / `make phpcbf` | Check / autofix Drupal coding standards (custom code only) |
| `make sniffers` / `make tests` | The pre-push gate / the full validation+test suite |
| `make front` / `make lint` / `make storybook` | Theme build / lint+fix / Storybook (need `THEME_NAME`) |
| `make xdebug on\|off\|status` | Toggle Xdebug |
| `make clean` | Tear the stack down and remove built code + DB |

To run **several stacks at once** (one per branch), see
[parallel-environments.md](parallel-environments.md).

## macOS (issue #400)

Docker volume performance and paths differ on macOS. Recommended `.env` overrides:

```sh
# Keep the SQLite DB on a bind mount, not /dev/shm
DB_URL=sqlite://./../.cache/db.sqlite
DB_DATA_DIR=../.cache
# Match your host user so files aren't root-owned
CUID=1000
CGID=1000
```

In `docker/docker-compose.override.yml` for the `php` service:

- Use the `:cached` volume flag instead of `:z` for the bind mount.
- If you need to hit the site without Traefik, publish a port (e.g. `ports: ["8090:80"]`).
- If DNS resolution misbehaves inside containers, add `dns: 8.8.8.8`.

The Makefile already special-cases Darwin in `scripts/makefile/system-detection.mk` (sets `CUID/CGID`
to 1000 and a longer compose timeout). **[OrbStack](https://docs.orbstack.dev/features)** is a
lighter-weight Docker Desktop alternative many on the team use on macOS.

## Troubleshooting

- **Port already in use / can't reach the site** — locally the `php` service publishes no host port by
  default; `make info` prints the container IP, or publish a port as above.
- **Permission errors on `web/sites` or `.cache`** — run the failing step via `make exec0` (root) once,
  or re-run `make si` which re-applies the settings permissions.
- **Stale containers from another branch** — each stack is keyed by `COMPOSE_PROJECT_NAME`; `make clean`
  in the right checkout, or see [parallel-environments.md](parallel-environments.md).
- **Pre-push hook rejects a push** — it runs `make sniffers`; fix the reported issues or bypass once
  with `git push --no-verify`.
