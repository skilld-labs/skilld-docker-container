#!/usr/bin/env sh
# set -x
set -eu

# Preparing
echo -e "\nEnabling module..."
drush pm:enable devel_generate -y

# Parsing command
PARSING_CMD='echo drush config:status --state=Any --format=list'


# Looking for languages
echo -e "\nLooking for languages..."

	# Entity to parse. Can be node.type or taxonomy.vocabulary for ex (see PARSING_CMD for more)
	ENTITY_TO_PARSE=language.entity

	# Languages "undefined" and "zxx" exist by default but are invisible in UI
	LANGUAGES_TO_EXCLUDE="und|zxx"

	# Count languages
	LANGUAGE_COUNT=$($($PARSING_CMD) | grep -vE "$LANGUAGES_TO_EXCLUDE" | grep -c $ENTITY_TO_PARSE)

	# Find languages
	LANGUAGES_FOUND=$($($PARSING_CMD) | grep -vE "$LANGUAGES_TO_EXCLUDE" | grep ^$ENTITY_TO_PARSE | awk -F "." '{print $3}' | tr '\n' ',' | sed 's/,$//')

	if [ "$LANGUAGE_COUNT" -gt "1" ]; then
		printf "- \033[1m$LANGUAGE_COUNT languages\033[0m found : "
		echo $LANGUAGES_FOUND
		printf "All content will be created with their translations !\n"
	else
		printf "- \033[1mOnly 1 language\033[0m found : $LANGUAGES_FOUND\n"
	fi

# Looking for bundles
echo -e "\nLooking for bundles..."

# Voc entity

	# Entity to parse. Can be node.type or taxonomy.vocabulary for ex (see PARSING_CMD for more)
	ENTITY_TO_PARSE=taxonomy.vocabulary

	# Count bundles
	BUNDLE_COUNT=$($($PARSING_CMD) | grep -c $ENTITY_TO_PARSE)

	if [ "$BUNDLE_COUNT" -gt "0" ]; then

		printf "- \033[1m$BUNDLE_COUNT Voc bundle(s)\033[0m found : "
		BUNDLES_FOUND=$($($PARSING_CMD) | grep ^$ENTITY_TO_PARSE | awk -F "." '{print $3}' | tr '\n' ',' | sed 's/,$//')
		echo $BUNDLES_FOUND

		echo "  Generating content..."
		VOC_GENERATE_COUNT=10

		BUNDLES_FOUND=$($($PARSING_CMD) | grep ^$ENTITY_TO_PARSE | awk -F "." '{print $3}')
		for voc_bundles in $BUNDLES_FOUND; do
			drush devel-generate-terms $VOC_GENERATE_COUNT --bundles=$voc_bundles --translations=$LANGUAGES_FOUND --quiet
			echo "  $VOC_GENERATE_COUNT terms have been created for $voc_bundles"
		done

	else
		printf "- \033[1mNo Voc bundle\033[0m found\n"
	fi

# CT entity

	# Entity to parse. Can be node.type or taxonomy.vocabulary for ex (see PARSING_CMD for more)
	ENTITY_TO_PARSE=node.type

	# Count bundles
	BUNDLE_COUNT=$($($PARSING_CMD) | grep -c $ENTITY_TO_PARSE)

	if [ "$BUNDLE_COUNT" -gt "0" ]; then

		printf "- \033[1m$BUNDLE_COUNT CT bundle(s)\033[0m found : "
		BUNDLES_FOUND=$($($PARSING_CMD) | grep ^$ENTITY_TO_PARSE | awk -F "." '{print $3}' | tr '\n' ',' | sed 's/,$//')
		echo $BUNDLES_FOUND

		echo "  Generating content..."
		CT_GENERATE_COUNT=30

		BUNDLES_FOUND=$($($PARSING_CMD) | grep ^$ENTITY_TO_PARSE | awk -F "." '{print $3}')
		for ct_bundles in $BUNDLES_FOUND; do
			drush devel-generate-content $CT_GENERATE_COUNT --bundles=$ct_bundles --translations=$LANGUAGES_FOUND --quiet
			echo "  $CT_GENERATE_COUNT nodes have been created for $ct_bundles"
		done

	else
		printf "- \033[1mNo CT bundle\033[0m found\n"
	fi


# Cleaning
echo -e "\nDisabling module..."
drush pmu devel_generate devel -y

# Informing
echo -e "\nFor more content, run this job multiple times or use Devel Generate Drupal UI.\n"
