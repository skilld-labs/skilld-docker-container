# Parallel local environments (git worktrees)

You can run **several full stacks at once on one machine** — one per branch — the same way CI runs one
review app per MR. This is the local equivalent of review apps, and it is what lets agents work on two
branches concurrently (each in its own worktree booting its own stack).

## Why it already works

The Makefile keys every Docker resource off `COMPOSE_PROJECT_NAME`:

- containers are named `${COMPOSE_PROJECT_NAME}_web`, the network is `${COMPOSE_PROJECT_NAME}_front`;
- `DB_MOUNT_DIR` is derived from `COMPOSE_PROJECT_NAME` + the working directory;
- compose calls are pinned to the local `.env` (`docker compose --env-file .env …`).

`.env` is per-checkout (gitignored, created from `.env.default`). So two checkouts with **different
`COMPOSE_PROJECT_NAME` values don't collide** — different containers, network, and DB storage.
`git worktree` gives you those separate checkouts cheaply, sharing one `.git`.

## Recipe

```sh
# from your main checkout
git worktree add ../sdc-feature-x feature-x      # new worktree for branch feature-x
cd ../sdc-feature-x
cp ../skilld-docker-container/.env .env 2>/dev/null || cp .env.default .env

# give THIS worktree a unique project name (or use the helper below)
sed -i 's/^COMPOSE_PROJECT_NAME=.*/COMPOSE_PROJECT_NAME=sdc_feature_x/' .env

make all                                          # boots an isolated stack for feature-x
```

The original checkout's stack keeps running; `make info` in each prints its own URL/logins. Tear one
down with `make clean` in that worktree, then `git worktree remove ../sdc-feature-x`.

### Optional helper

[`scripts/makefile/worktree.mk`](../scripts/makefile/worktree.mk) provides `make worktree-name`, which
derives a sanitized `COMPOSE_PROJECT_NAME` from the current git branch (or worktree directory) and
writes it into `.env` — so you don't hand-edit it per worktree. Run it once after creating the
worktree, before `make all`.

## Caveats (shared host resources)

A few things are **not** namespaced by `COMPOSE_PROJECT_NAME`; vary them per worktree to avoid clashes:

| Resource | Collision | Fix per worktree |
| --- | --- | --- |
| `MAIN_DOMAIN_NAME` (Traefik `Host` rule) | Two stacks claiming `docker.localhost` | Set a distinct host, e.g. `featurex.docker.localhost` |
| `/dev/shm` SQLite (`make fast`/`allfast`) | Fixed path `sqlite:///dev/shm/db.sqlite` shared on the host | Use the default per-dir `.cache` DB (don't use `fast`) for parallel stacks |
| Published host `ports:` (if you uncommented any, e.g. macOS `8090:80`) | Same host port twice | Give each worktree a different host port |
| Host RAM / CPU | N stacks = N× resource use | Keep the number sane; `make clean` idle ones |

If you stick to the defaults (Traefik routing by hostname, per-dir SQLite, no published ports), the
only thing you must set per worktree is `COMPOSE_PROJECT_NAME` (and `MAIN_DOMAIN_NAME` if you use
Traefik locally).

## Agent tie-in

Claude Code can run agents in **isolated worktrees** (`Agent` with `isolation: "worktree"`, or the
Workflow tool). Combined with the above, each agent boots its own stack, so the `drupal-upgrade` branch
and a fix branch can build and be tested **at the same time** without stepping on each other. See
[`.claude/README.md`](../.claude/README.md) and [CONTRIBUTING.md](../CONTRIBUTING.md#agent-harness).
