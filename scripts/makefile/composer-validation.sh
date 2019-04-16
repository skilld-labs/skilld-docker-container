#!/usr/bin/env sh

# Get command result and its exit code
COMMAND=$(composer validate --strict --quiet)
COMMAND_EXIT_CODE=$(echo $?)

# Exit1 and alert if not ok, otherwise remain silent
if [[ "$COMMAND_EXIT_CODE" != "0" ]]; then
	composer validate --strict
	exit 1
else
	exit 0
fi
