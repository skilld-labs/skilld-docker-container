---
name: backlog-grooming
description: Triage the open GitHub PRs and issues — classify into adopt-now / rebase / fold-into-docs / close, dedupe, and regenerate docs/backlog.md. Use for "groom the backlog", "triage issues", "what should we do with the open PRs".
---

# Backlog grooming

Keep [docs/backlog.md](../../../docs/backlog.md) current and the queue actionable. Read-only against
GitHub except for editing `docs/backlog.md`.

## Steps

1. **Enumerate** (read-only):
   - `gh pr list --state open --limit 100`
   - `gh issue list --state open --limit 200`
2. **Inspect** the substantive ones: `gh pr view <n> --comments`, `gh pr diff <n> --stat`,
   `gh issue view <n> --comments`. For each, note: what it does, files touched, staleness, and whether
   master already solved it.
3. **Classify** into the buckets used in `docs/backlog.md`:
   - **adopt-now** — small, low-risk, still applies.
   - **rebase & finish** — valuable but stale/conflicting.
   - **fold into docs** — no code needed; the answer is documentation.
   - **close** — obsolete, superseded, or abandoned.
4. **Dedupe** — link PRs to their issues (e.g. an "auto shm size" PR and its issue) and collapse.
5. **Cross-check against the repo**: before recommending adopt, confirm the change isn't already in
   master (`git log`, current `composer.json`/`Makefile`). Several issues are already resolved (e.g.
   #467 Unit default, #341 shm size).
6. **Regenerate** `docs/backlog.md` with the updated table and a suggested order. Keep the markdown
   table shape.

## Output
- Updated `docs/backlog.md`.
- A short summary: counts per bucket, and the top 3 recommended actions.

## Guardrails
- Don't close/comment on GitHub from here — produce the recommendation; a human (or an explicit
  follow-up) acts on it.
- Note any PR that conflicts with in-flight work (e.g. #403 k3s vs the worktree helper).
