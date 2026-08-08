# Delivery & ops helpers

Beyond review apps, `scripts/` ships **opt-in** recipes for delivering builds and mirroring repos.
Each is an *example* meant to be copied into a consuming project's pipeline — none runs by default.
This page indexes them; each linked README has the exact CI job and variables.

All of them exist for the same reasons: built **artifacts (composer/yarn output) are not versioned in
git**, GitLab's built-in mirroring/registry **doesn't work when the repo is behind basic auth**, and
**multi-target mirroring is often a paid feature**.

## Delivery (on tag, to a release target)

| Helper | Delivers | Extra file needed | Key CI/CD variables | README |
| --- | --- | --- | --- | --- |
| **Archive** | Current tag as a `.tar.gz` to a raw file registry | — | `DELIVERY_REPOSITORIES_RAW_REGISTRY_DOMAIN_1`, `…_USERNAME`, `…_PASSWORD` | [scripts/delivery-archive](../scripts/delivery-archive/README.md) |
| **Docker** | Current tag as a Docker image to a registry | `scripts/delivery-docker/Dockerfile` | `DELIVERY_REPOSITORIES_DOCKER_REGISTRY_DOMAIN_1`, `…_USERNAME`, `…_PASSWORD` | [scripts/delivery-docker](../scripts/delivery-docker/README.md) |
| **Git** | Current tag pushed to another git repo (e.g. Platform.sh) | `scripts/delivery-git/deliver_current_tag_via_git.sh` | `DELIVERY_REMOTE_REPO_{IP,PRIVATE_KEY,TYPE,URL_1,BRANCH}`, `GIT_USER_{EMAIL,NAME}` | [scripts/delivery-git](../scripts/delivery-git/README.md) |

Each supports **multiple targets at once** by adding more jobs (`…_DOMAIN_2`, `…_URL_2`, …). Position
the delivery job after `prepare:back`/`prepare:front` and use `dependencies:` so the built artifacts
are present.

## Mirroring (on every branch)

| Helper | Action | Extra file | Key variables | README |
| --- | --- | --- | --- | --- |
| **Mirroring** | Mirror the current branch to other repos; also deletes remote branches absent locally | `mirror_current_branch.sh` | `MIRRORING_REMOTE_REPO_{IP,PRIVATE_KEY,TYPE,URL_1}`, `GIT_USER_{EMAIL,NAME}` | [scripts/mirroring](../scripts/mirroring/README.md) |

## Multisite (config_split switching)

[scripts/multisite](../scripts/multisite/README.md) lets a multisite setup swap config sets quickly,
locally and in review apps:

1. `composer require drupal/config_split` and create splits in the UI (no split for the shared
   `default` case).
2. Move `config_split.mk` + `config_split_disable_all.sh` into `scripts/makefile/`.
3. Locally: `make split first` / `make split default`. In CI: manual jobs per split; review apps build
   with the `default` split.

## Relationship to review apps

These run in the **same pipeline** as the review-app jobs ([ci-pipeline.md](ci-pipeline.md)) but in
their own stage (`deliver` / `mirror`), typically on tags. Review apps are for *validation before
merge/release*; delivery/mirroring is for *shipping the validated result onward*.
