---
name: review-app-triage
description: Triage a failing review app or local stack — pull pipeline, Behat (junit), Lighthouse, and watchdog output, then localize the failure and propose a fix. Use when a review app build or a test:* job is red, or when "why did the pipeline fail".
---

# Review-app triage

Goal: turn a red pipeline / broken stack into a localized root cause and a concrete fix. Wraps the
project's own validation targets — see [docs/ci-pipeline.md](../../../docs/ci-pipeline.md) and
[docs/review-apps.md](../../../docs/review-apps.md).

## Inputs
- A GitLab pipeline/job URL or ID, **or** a local stack that is misbehaving.
- The branch/MR under review.

## Steps

1. **Identify the failing stage.** Map the job to its `make` target using the table in
   [ci-pipeline.md](../../../docs/ci-pipeline.md#job--make-target--script-map). The likely culprits:
   - `build:*` red → install failed: re-run `make all_ci` (or `make all` locally) and read the first
     error; usually composer resolution or `drush si`.
   - `test:behat` red → read the **JUnit** artifact (`junit/*.xml`) and the screenshots (Behat writes
     them to `features/`; in CI they are moved to `web/screenshots/` and served on the review URL).
     Reproduce locally with `make behat`.
   - `test:cinsp` / `test:upgradestatus` / `test:statusreport` / `test:watchdog` red → run the same
     target locally (`make cinsp`, `make upgradestatusval`, …); each prints the offending file/config/log.
   - `test:lighthouse` red → a category dropped below the `lighthouserc.yml` threshold; read
     `web/lighthouseci/*.html`.
2. **Pull logs.** For a running stack: `docker compose logs --tail=200 php` and
   `make drush -- watchdog:show --severity=Error --count=50`. See
   [docs/observability.md](../../../docs/observability.md).
3. **Reproduce locally** in an isolated worktree if possible
   ([parallel-environments.md](../../../docs/parallel-environments.md)) so you don't disturb other work.
4. **Localize** to a file/commit. Use `git log -p` on the suspect path; compare against the last green
   pipeline.
5. **Report**: the failing job, the exact error, the root-cause file/line, and a proposed fix. For deep
   log reading, delegate to the [`ci-log-analyzer`](../../agents/ci-log-analyzer.md) subagent.

## Notes
- Respect the test-ordering constraint (#323): if you re-order jobs, keep `cinsp` before the
  schema-mutating checks.
- Don't mark anything fixed until the relevant `make <target>` passes locally.
