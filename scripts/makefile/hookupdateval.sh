#!/usr/bin/env sh

# Get count of modified field storage config object
FIELD_STORAGE_COUNT=$(git show --name-status | grep "^M" | grep -c field.storage )

if [ "$FIELD_STORAGE_COUNT" -gt "0" ]; then
  # If storage changed we need new hook_updates in install file.
  UPDATE_COUNT=$(git show web/modules/custom/*.install | grep "^\+" | grep -c _update_ )
  if [ "$UPDATE_COUNT" -gt "0" ]; then
    printf "hook_update_N() has been included for storage changes."
    exit 0
  else
    printf "hook_update_N() missing for storage changes:\n- A config update has occured which requires a hook_update to be properly deployable on live site.\n"
    exit 1
  fi
else
	echo "OK : No changes in field storage."
	exit 0
fi
