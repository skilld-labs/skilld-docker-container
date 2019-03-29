#!/usr/bin/env sh

# pre-commit.sh
STASH_NAME="pre-commit-$(date +%s)"
git stash save -q --keep-index $STASH_NAME

# Bold and normal formating
bold=$(tput bold)
normal=$(tput sgr0)

# langcode logic
if [ -r config/sync/*.system.site.yml ]
then
	printf "\n*.system.site.yml file exists\n"

	# Display the site settings config file (if it exists) + save it in a variable
	SITE_SETTINGS_FILE_PATH=$(find config/sync -type f -name "*.system.site.yml")
	printf "Its path is : $SITE_SETTINGS_FILE_PATH\n"

	# Display Drupal default language as defined in the site settings config file + save it in a variable
	DEFAULT_SITE_LANG_VALUE=$(awk -v pattern="default_langcode" '$1 ~ pattern { print $NF }' config/sync/*.system.site.yml)
	printf "Default site language is : \e[32m$DEFAULT_SITE_LANG_VALUE\e[0m\n\n"

	# Display the language defined in each of the basic config files + save them in a variable
	LANG_VALUE_IN_BASE_CONFIG_FILES=$(awk '$1 ~ /^langcode/ { print $NF }' config/sync/*.yml | grep -wE '\w{1,2}' | sort | uniq)
	#printf "LANG_VALUE_IN_BASE_CONFIG_FILES :\n$LANG_VALUE_IN_BASE_CONFIG_FILES\n\n"

	# NAME_OF_BASE_CONFIG_FILES=$(grep -R 'langcode' config/sync/*.yml -l)
	#printf "NAME_OF_BASE_CONFIG_FILES :\n$NAME_OF_BASE_CONFIG_FILES\n\n"

	printf "\e[33mChecking lang for each file...\e[0m\n"
	# Defining value of MESSAGE_OUTPUT variable
	MESSAGE_OUTPUT="\n${bold}The language of some base config files is NOT matching site default language ${normal}(\e[32m$DEFAULT_SITE_LANG_VALUE\e[0m) :"
	FAIL=0

	# For each file, compare the language of base config files against default site language
	for lang in $LANG_VALUE_IN_BASE_CONFIG_FILES; do
		if [ "$lang" != "$DEFAULT_SITE_LANG_VALUE" ]
		then
			FAIL=1
			MESSAGE_OUTPUT="$MESSAGE_OUTPUT \n${bold} - langcode \e[31m$lang\e[0m ${bold}was found in $(grep -R "langcode: $lang" config/sync/*.yml -l | wc -l) file(s)${normal}\n$(grep -R "langcode: $lang" config/sync/*.yml -l)"
		fi
	done
	if [ $FAIL -eq 1 ]
	then
		echo "$MESSAGE_OUTPUT \n\n\e[33mBase configs should always be in same language as default site language.\e[0m\n\n${bold}\e[31mCOMMIT REJECTED!${normal}\e[0m\nTo bypass validation, use git commit --no-verify\n""
	else
		echo "\e[33mLangage of all base config files is matching default site language. You are good to go!\e[0m\n"
	fi
	exit $FAIL
else
	echo "*.system.site.yml file does not exist"
	exit 1
fi

# post-commit.sh
STASHES=$(git stash list)
if [[ $STASHES == "$STASH_NAME" ]]; then
  git stash pop -q
fi
