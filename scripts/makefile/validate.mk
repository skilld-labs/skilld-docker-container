# Static validation of the docs + .claude/ agent harness (Tier 0 of docs/testing.md).
# Needs only Node (no Drupal stack) — runs the validator in the front node image.
# Auto-included by the root Makefile's `include scripts/makefile/*.mk`.

.PHONY: harnessval

IMAGE_FRONT ?= node:lts-alpine

## Validate docs links + the .claude/ agent harness (no containers/site needed)
harnessval:
	@echo "Harness static gate (docs links, settings.json, workflows, frontmatter, doc/CI drift)..."
	docker run --rm --init -u $(CUID):$(CGID) -v $(CURDIR):/app -w /app $(IMAGE_FRONT) node scripts/ci/validate-harness.mjs
