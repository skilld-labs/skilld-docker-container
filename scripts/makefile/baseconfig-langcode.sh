#!/usr/bin/env sh

# Checking langcode of base config files
if [ -r config/sync/system.site.yml ]
then

	# Get the site settings config file (if it exists) + save it in a variable
	SITE_SETTINGS_FILE_PATH=$(find config/sync -maxdepth 1 -type f -name "system.site.yml")

	# Get Drupal default language as defined in the site settings config file + save it in a variable
	# DEFAULT_SITE_LANG_VALUE=$(awk -v pattern="default_langcode" '$1 ~ pattern { print $NF }' config/sync/system.site.yml)
	DEFAULT_SITE_LANG_VALUE=$(awk -v pattern="default_langcode" '$1 ~ pattern { print $NF }' config/sync/system.site.yml)

	# Get the language defined in each of the basic config files + save them in a variable
	LANG_VALUE_IN_BASE_CONFIG_FILES=$(grep -E "^langcode:" config/sync/*.yml | awk '{print $2}' | sort | uniq)

	# Defining value of MESSAGE_OUTPUT variable
	MESSAGE_OUTPUT="\nThe language of some base config files is NOT matching site default language (\e[32m$DEFAULT_SITE_LANG_VALUE\e[0m) :"
	FAIL=0

	# For each file, compare the language of base config files against default site language
	for lang in $LANG_VALUE_IN_BASE_CONFIG_FILES; do
		if [ "$lang" != "$DEFAULT_SITE_LANG_VALUE" ]
		then
			FAIL=1
			MESSAGE_OUTPUT="$MESSAGE_OUTPUT \n - langcode \e[31m$lang\e[0m was found in $(grep -rE "^langcode: $lang" config/sync/*.yml -l | wc -l) file(s)\n$(grep -rE "^langcode: $lang" config/sync/*.yml -l)"
		fi
	done
	if [ $FAIL -eq 1 ]
	then
		echo -e "$MESSAGE_OUTPUT \n\n\e[33mBase configs should have the same langcode as default site language.\n"
	else
		echo "Langcode of config files are valid"
	fi
	exit $FAIL
fi
