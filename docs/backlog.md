# Backlog triage

A decision list for the open PRs and issues on
[skilld-labs/skilld-docker-container](https://github.com/skilld-labs/skilld-docker-container), so the
queue is actionable rather than unbounded. Snapshot taken during the documentation effort; regenerate
with the [`backlog-grooming`](../.claude/skills/backlog-grooming/SKILL.md) skill.

Buckets: **adopt-now** (small, low-risk), **rebase & finish** (valuable, stale), **fold into docs**
(no code needed), **close** (stale/obsolete/superseded).

## Pull requests

| PR | Title | Bucket | Note |
| --- | --- | --- | --- |
| #466 | Open Telemetry tracing | **rebase & finish** | Observability Tier 2; finish TODOs (RA collector, optional flag, dashboards). See [observability.md](observability.md) |
| #290 | Add local composer cache | **adopt-now** | One line; low risk |
| #189 | Lock node image version | **adopt-now** | Reported mergeable; verify the pin is still sensible |
| #279 | Yarn cache on local + RA | **rebase** | Complements #290; re-test against current `.gitlab-ci.yml` |
| #342 | Auto-set shm size | **rebase / maybe close** | Largely superseded by compose `shm_size` (closed #451); keep only if it adds value |
| #403 | k3s alternative to compose | **defer** | Large, invasive Makefile refactor; **conflicts with the worktree helper** — decide its fate before Workstream 6 lands |
| #271 | Add modules to install profile | **needs info / close** | Unclear module list; revisit post-D11 |
| #141 | Try GitHub Actions | **close** | 7-yr-old probe; GitLab CI is the platform |
| #38 | macOS shared folder `cached` | **close** | Based on a deprecated Docker Desktop option; macOS guidance now in [local-development.md](local-development.md) |

## Issues

| Issue | Title | Bucket | Action |
| --- | --- | --- | --- |
| #461 | Prepare Drupal 11 upgrade | **adopt-now** | Tracked by [upgrading.md](upgrading.md); **blocked on a D11-capable druxxy** |
| #467 | Nginx Unit as default | **close (done)** | Unit is already the default again (commit `35a7f38`); rationale documented in [architecture.md](architecture.md) |
| #323 | Order for tests | **fold into docs** | `cinsp`-before-schema-mutators captured in [ci-pipeline.md](ci-pipeline.md#test-ordering-constraint-issue-323) |
| #287 | Dotenv for dynamic environments | **adopt** | `artifacts:reports:dotenv` for the review URL; noted in [ci-pipeline.md](ci-pipeline.md#opportunities-tracked-in-the-backlog) |
| #295 | Adopt code-quality for GitLab | **adopt** | Emit `artifacts:reports:codequality` from phpcs/rector |
| #152 | Add health checks | **adopt** | Unit health route → `healthcheck:`; see [observability.md](observability.md) and [architecture.md](architecture.md) |
| #400 | macOS local setup | **fold into docs (done)** | Captured in [local-development.md](local-development.md#macos-issue-400) |
| #70 | Inspection workflow (proposed `insp` target) | **consider** | Consolidate inspection targets; aligns with the agent skills |
| #341 | Auto-set shm size | **close** | Solved by closed #451 (compose `shm_size`) |
| #210 | composer-lock-diff | **fold into docs** | Optional CI nicety |
| #195 | Static storybook build | **fold into docs** | Covered by `make build-storybook` + #287 link injection |
| #164 | New core templates/scaffold | **fold into docs** | Re-evaluate against D11 scaffold |
| #160 | Revamp `clean` task | **consider** | Constraints on `web/sites/*` cleanup |
| #18 | Windows support | **fold into docs** | Path-separator / `-d` notes |
| #10 | Access sites by domain name | **fold into docs** | DNS / `/etc/hosts` pattern; relates to [parallel-environments.md](parallel-environments.md) |
| #144, #142, #179 | Drush 9 config / profile hook / node image | **close** | Obsolete (Drush 13 now) |
| #414, #59, #58, #26, #25, #14, #13, #50 | misc 2016–2022 | **close** | Stale; no concrete scope |

## Suggested order

1. **adopt-now**: #290, #189 (quick wins).
2. **fold into docs**: already done for #323/#400/#467; do #287/#295 next (small CI templating).
3. **rebase & finish**: #466 (observability) — highest-value stale PR.
4. **decide #403** before the worktree helper to avoid a Makefile rebase collision.
5. **close** the stale set in one grooming pass.
