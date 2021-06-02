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
echo -e "- Looking for splits of config..."

if [ "$CONFIG_COUNT" -gt "0" ]; then

	echo -e "- Some splits were found : Disabling all splits..."

	for bundles in $CONFIG_LIST; do
		drush config-set config_split.config_split.$bundles status 0 -y
	done

else
	printf "- \033[1mNo split of config was\033[0m found\n"
fi

echo -e "- Clearing cache..."
drush cr
