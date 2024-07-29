#!/usr/bin/env sh
# Enable config inspector module before inspection.
drush pm:enable config_inspector -y

# Get count of config inspector errors
ERROR_COUNT=$(drush config:inspect --only-error --format=string | tail -n +3 | wc -l)

# Exit1 and alert if logs
if [ "$ERROR_COUNT" -gt "0" ]; then
	printf "\n- \033[1m$ERROR_COUNT error(s)\033[0m identified by config_inspector to fix :\n"
	drush config:inspect --only-error --detail
	echo -e "\nConfiguration is not valid : \n- Go to \033[1m/admin/config/development/configuration/inspect\033[0m for more details\n"
	exit 1
else
	drush pmu config_inspector -y
	echo -e "Configuration is valid"
	exit 0
fi
