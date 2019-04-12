#!/usr/bin/env sh

# Get command result
COMMAND=$(composer validate --strict)

# Exit1 and alert if not ok, otherwise remain silent
if [[ "$COMMAND" != "./composer.json is valid" ]]; then
	composer validate --strict
	exit 1
else
	exit 0
fi
