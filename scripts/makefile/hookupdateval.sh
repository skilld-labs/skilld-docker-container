#!/usr/bin/env sh

# Count config updates to watch for
FIELD_STORAGE_COUNT=$(git show --name-status | grep "^M" | grep -c field.storage )
EXTENSIONS_DISABLED_COUNT=$(git show --shortstat -- config/*/*core.extension* | grep -c deletion)

if [ "$FIELD_STORAGE_COUNT" -gt "0" ] || [ "$EXTENSIONS_DISABLED_COUNT" -gt "0" ]; then
  # If watched config was updated, we need new hook_updates in install file
  UPDATE_COUNT=$(git show web/modules/custom/*.install | grep "^\+" | grep -c _update_ )
  if [ "$UPDATE_COUNT" -gt "0" ]; then
    printf "hook_update_N() has been included for watched config changes.\n"
    exit 0
  else
    printf "\033[1mERROR: hook_update_N() missing for next reason(s):\n"
    if [ "$FIELD_STORAGE_COUNT" -gt "0" ]; then
      printf " - A field storage config update has occured which requires a hook_update to be properly deployable on live site.\n"
    fi
    if [ "$EXTENSIONS_DISABLED_COUNT" -gt "0" ]; then
      printf " - Some module has been disabled (and possibly removed), so, need hook_update which will remove all modules data during deploy on live site.\n"
    fi
    printf "Please include missing hook_updates(s)\n"
    exit 1
  fi
else
  echo "OK : No change requires a hook_update_N()\n"
  exit 0
fi
