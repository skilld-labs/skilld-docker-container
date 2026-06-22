# Helpers for running several isolated stacks in parallel, one per git worktree.
# See docs/parallel-environments.md. Auto-included by the root Makefile's `include scripts/makefile/*.mk`.
# Note: `sed -i` differs on BSD (macOS) vs GNU (Linux); the recipe branches on uname.

.PHONY: worktree-name

## Derive COMPOSE_PROJECT_NAME (and a matching MAIN_DOMAIN_NAME) from the current git branch into .env
worktree-name:
	@branch=$$(git rev-parse --abbrev-ref HEAD 2>/dev/null || basename $(CURDIR)); \
	name=$$(echo "$$branch" | tr -cd '[:alnum:]' | tr '[:upper:]' '[:lower:]'); \
	[ -n "$$name" ] || name=$$(basename $(CURDIR) | tr -cd '[:alnum:]' | tr '[:upper:]' '[:lower:]'); \
	[ -f .env ] || cp .env.default .env; \
	if [ "$$(uname)" = "Darwin" ]; then \
		sed -i '' -e "/^COMPOSE_PROJECT_NAME=/ s/=.*/=$$name/" .env; \
		sed -i '' -e "/^MAIN_DOMAIN_NAME=/ s/=.*/=$$name.docker.localhost/" .env; \
	else \
		sed -i -e "/^COMPOSE_PROJECT_NAME=/ s/=.*/=$$name/" .env; \
		sed -i -e "/^MAIN_DOMAIN_NAME=/ s/=.*/=$$name.docker.localhost/" .env; \
	fi; \
	echo "Worktree env set in .env:"; \
	echo "  COMPOSE_PROJECT_NAME=$$name"; \
	echo "  MAIN_DOMAIN_NAME=$$name.docker.localhost   (from branch '$$branch')"; \
	echo "Now run 'make all' to boot this worktree's isolated stack."
