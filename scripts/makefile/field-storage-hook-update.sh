#!/usr/bin/env sh

# Get count of modified field storage config object
FIELD_STORAGE_COUNT=$(git show --name-status | grep "^M" | grep field.storage | wc -l)

if [ "$FIELD_STORAGE_COUNT" -gt "0" ]; then
  # If storage changed we need new hook_updates in install file.
  UPDATE_COUNT=$(git show web/modules/custom/*.install | grep "^\+" | grep _update_ | wc -l)
  if [ "$UPDATE_COUNT" -gt "0" ]; then
    printf "hook_update_N() included for storage changes."
    exit 0
  else
    printf "hook_update_N() missing for storage changes."
    exit 1
  fi
else
	echo -e "No changes in field storage."
	exit 0
fi
