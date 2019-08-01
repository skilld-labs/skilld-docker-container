#!/usr/bin/env sh

# Define messages to watch for
## Possible values : 2=error, 1=warning, and 0/-1=OK
MESSAGES_SEVERITY="2"

## Messages to ignore
## Separate with pipe : |
# IGNORED_MESSAGES="Trusted Host Settings"
IGNORED_MESSAGES="Trusted Host Settings"

# Get count of messages
MESSAGE_COUNT=$(drush status-report --severity=$MESSAGES_SEVERITY --filter="title~=/^(?!$IGNORED_MESSAGES$)/i" --format=string | wc -l)

# Exit1 and alert if count > 0
if [ "$MESSAGE_COUNT" -gt "0" ]; then
	printf "There are \033[1m$MESSAGE_COUNT message(s)\033[0m in status report to fix :\n"
	drush status-report --severity=$MESSAGES_SEVERITY --filter="title~=/^(?!$IGNORED_MESSAGES$)/i"
	exit 1
else
	echo -e "Status report is valid : No error listed"
	exit 0
fi
