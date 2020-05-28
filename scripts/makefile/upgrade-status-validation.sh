#!/usr/bin/env sh

# Enable Upgrade Status module
drush en -y upgrade_status

# Search for no issues message
REPORT=$(drush us-a --all --ignore-contrib --ignore-uninstalled)
IS_VALID=$(echo "$REPORT" | grep "No known issues found.")

# Exit1 and alert if message not found
if [ -z "$IS_VALID" ]; then
  printf "There are \033[1mmessage(s)\033[0m in Upgrade Status report to fix :\n"
	echo -e "$REPORT"
	exit 1
else
  echo -e "Status report is valid : No error listed"
	exit 0
fi
