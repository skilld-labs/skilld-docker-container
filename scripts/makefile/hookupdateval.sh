#!/usr/bin/env sh
# set -x

# Get name of parent branch...
if [ -z "$CI_MERGE_REQUEST_TARGET_BRANCH_NAME" ]; then
  # ... when not in Gitlab CI
  PARENT_BRANCH=$(git show-branch | sed "s/].*//" | grep "\*" | grep -v "$(git rev-parse --abbrev-ref HEAD)" | head -n1 | sed "s/^.*\[//")
else
  # ... when in Gitlab CI
  PARENT_BRANCH=$CI_MERGE_REQUEST_TARGET_BRANCH_NAME
fi

# Diff current branch against parent branch and make validation
git fetch -q origin "$PARENT_BRANCH"
FIELD_STORAGE_CHANGE_COUNT=$(git diff origin/"$PARENT_BRANCH" --name-only --diff-filter=M | grep -c field.storage)
CORE_EXTENSION_DELETION_COUNT=$(git diff origin/"$PARENT_BRANCH" --shortstat -- config/*/*core.extension* | grep -c deletion)

if [ "$FIELD_STORAGE_CHANGE_COUNT" -gt "0" ] || [ "$CORE_EXTENSION_DELETION_COUNT" -gt "0" ]; then
  # If watched config was updated, we need new hook_updates in install file
  HOOKUPDATE_ADDITION_COUNT=$(git diff origin/"$PARENT_BRANCH" web/modules/custom/*.install | grep "^\+" | grep -c _update_ )
  if [ "$HOOKUPDATE_ADDITION_COUNT" -gt "0" ]; then
    printf "hook_update_N() has been included for watched config changes.\n"
    exit 0
  else
    printf "\033[1mERROR: hook_update_N() missing for next reason(s):\n"
    if [ "$FIELD_STORAGE_CHANGE_COUNT" -gt "0" ]; then
      printf " - A field storage config update has occured which requires a hook_update to be properly deployable on live site.\n"
    fi
    if [ "$CORE_EXTENSION_DELETION_COUNT" -gt "0" ]; then
      printf " - Some module has been disabled (and possibly removed), so, need hook_update which will remove all modules data during deploy on live site.\n"
    fi
    printf "Please include missing hook_updates(s)\n"
    exit 1
  fi
else
  printf "OK : No change requires a hook_update_N()\n"
  exit 0
fi
