#!/usr/bin/env sh

# Parsing command
PARSING_CMD='echo drush config:status --state=Any --format=list'

# Entity to parse (see PARSING_CMD for more)
CONFIG_TO_PARSE=config_split.config_split

# Count entities
CONFIG_COUNT=$($($PARSING_CMD) | grep -c $CONFIG_TO_PARSE)

# List entities
CONFIG_LIST=$($($PARSING_CMD) | grep $CONFIG_TO_PARSE | awk -F "." '{print $3}')


# Looking for splits

if [ "$CONFIG_COUNT" -gt "0" ]; then

	echo -e "- The following splits are available : "

	for bundles in $CONFIG_LIST; do
		echo "   - $bundles"
	done
	printf "\n"

else
	printf "- \033[1mNo split of config was\033[0m found\n"
fi
