#!/usr/bin/env sh
# set -x

NON_REMOTE_PATCH_COUNT=$(jq --raw-output '.extra.patches[] | .[]' composer.json | grep -v "http" | wc -l)

if [ "$NON_REMOTE_PATCH_COUNT" -gt "0" ]; then
  # If patch file was added, throw error
  printf "\033[1mERROR: A non-remote patch was found in composer.json:\n"
  printf " - Patches should not be commited to project repos\n"
  printf " - They should be systematically published on Drupal.org, Github or any other upstream repo, to a new or existing issue\n\n"
  exit 1
else
  printf "OK : No local patch added to repo\n"
  exit 0
fi
