#!/usr/bin/env sh

# Define messages to watch for
## Separate with pipe : |
## Possible values : Emergency|Alert|Critical|Error|Warning|Notice|Info|Debug
MESSAGES_SEVERITY="Emergency|Alert|Critical|Error"

# Get count of watchlog logs
LOG_COUNT=$(drush watchdog-show --filter="severity~=#($MESSAGES_SEVERITY)#" --format=string | wc -l)

# Exit1 and alert if logs
if [ "$LOG_COUNT" -gt "0" ]; then
	printf "There are \033[1m$LOG_COUNT messages\033[0m in logs to fix :\n"
	drush watchdog-show --filter="severity~=#($MESSAGES_SEVERITY)#" --format=string --extended --count=100
	exit 1
else
	echo -e "Watchdog is valid : No message of high severity in logs ($MESSAGES_SEVERITY)"
	exit 0
fi
