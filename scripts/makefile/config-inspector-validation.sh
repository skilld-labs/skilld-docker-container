#!/usr/bin/env sh
# Enable config inspector module before inspection.
drush pm:enable config_inspector -y

# Get count of config inspector errors
ERROR_COUNT=$(drush config:inspect --only-error --format=string | wc -l)

# Exit1 and alert if logs
if [ "$ERROR_COUNT" -gt "0" ]; then
	printf "There are \033[1m$ERROR_COUNT errors\033[0m identified by config_inspector to fix :\n"
	drush config:inspect --only-error
	exit 1
else
	echo -e "Configuration is valid"
	exit 0
fi
