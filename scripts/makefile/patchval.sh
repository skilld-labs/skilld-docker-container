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
PATCH_FILE_COUNT=$(git diff origin/"$PARENT_BRANCH" --name-status --diff-filter=A | grep -c "\.patch")

if [ "$PATCH_FILE_COUNT" -gt "0" ]; then
  # If patch file was added, throw error
  printf "\033[1mERROR: A patch was found in commit:\n"
  printf " - Patches should not be commited to project repos\n"
  printf " - They should be systematically published on Drupal.org, Github or any other upstream repo, to a new or existing issue\n\n"
  exit 1
else
  printf "OK : No patch was added to repo\n"
  exit 0
fi
