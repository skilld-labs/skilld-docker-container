#!/usr/bin/env sh

# Bold and normal formating
bold=$(tput bold)
normal=$(tput sgr0)

# Checking langcode of base config files
if [ -r config/sync/system.site.yml ]
then

	# Get the site settings config file (if it exists) + save it in a variable
	SITE_SETTINGS_FILE_PATH=$(find config/sync -maxdepth 1 -type f -name "system.site.yml")

	# Get Drupal default language as defined in the site settings config file + save it in a variable
	DEFAULT_SITE_LANG_VALUE=$(awk -v pattern="default_langcode" '$1 ~ pattern { print $NF }' config/sync/system.site.yml)

	# Get the language defined in each of the basic config files + save them in a variable
	LANG_VALUE_IN_BASE_CONFIG_FILES=$(awk '$1 ~ /^langcode/ { print $NF }' config/sync/*.yml | grep -wE '\w{1,2}' | sort | uniq)

	# Defining value of MESSAGE_OUTPUT variable
	MESSAGE_OUTPUT="\n${bold}The language of some base config files is NOT matching site default language ${normal}(\e[32m$DEFAULT_SITE_LANG_VALUE\e[0m) :"
	FAIL=0

	# For each file, compare the language of base config files against default site language
	for lang in $LANG_VALUE_IN_BASE_CONFIG_FILES; do
		if [ "$lang" != "$DEFAULT_SITE_LANG_VALUE" ]
		then
			FAIL=1
			MESSAGE_OUTPUT="$MESSAGE_OUTPUT \n${bold} - langcode \e[31m$lang\e[0m ${bold}was found in $(grep -Re "^langcode: $lang" config/sync/*.yml -l | wc -l) file(s)${normal}\n$(grep -Re "^langcode: $lang" config/sync/*.yml -l)"
		fi
	done
	if [ $FAIL -eq 1 ]
	then
		echo "$MESSAGE_OUTPUT \n\n\e[33mBase configs should always be in same language as default site language.\e[0m\n\n${bold}\e[31mCOMMIT REJECTED!${normal}\e[0m\n"
	fi
	exit $FAIL
fi
