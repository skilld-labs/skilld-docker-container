#!/usr/bin/env sh

# Parsing command
PARSING_CMD='echo drush config:status --state=Any --format=list'

echo -e "\nLooking for bundles ..."

# Voc entity

	# Entity to parse. Can be node.type or taxonomy.vocabulary for ex
	ENTITY_TO_PARSE=taxonomy.vocabulary

	# Count bundles
	BUNDLE_COUNT=$($($PARSING_CMD) | grep -c $ENTITY_TO_PARSE)

	if [ "$BUNDLE_COUNT" -gt "0" ]; then

		printf "- \033[1m$BUNDLE_COUNT Voc bundle(s)\033[0m found : "
		BUNDLES_FOUND=$($($PARSING_CMD) | grep $ENTITY_TO_PARSE | awk -F "." '{print $3}' | tr '\n' ',' | sed 's/,$//')
		echo $BUNDLES_FOUND

		echo "  Generating content..."
		GENERATE_COUNT=20

		# TODO : Update after https://www.drupal.org/project/devel/issues/3073850
		BUNDLES_FOUND=$($($PARSING_CMD) | grep $ENTITY_TO_PARSE | awk -F "." '{print $3}')
		for voc_bundles in $BUNDLES_FOUND; do
			drush devel-generate-terms $voc_bundles $GENERATE_COUNT
		done

	else
		printf "- \033[1mNo Voc bundle\033[0m found\n"
	fi

# CT entity

	# Entity to parse. Can be node.type or taxonomy.vocabulary for ex
	ENTITY_TO_PARSE=node.type

	# Count bundles
	BUNDLE_COUNT=$($($PARSING_CMD) | grep -c $ENTITY_TO_PARSE)

	if [ "$BUNDLE_COUNT" -gt "0" ]; then

		printf "- \033[1m$BUNDLE_COUNT CT bundle(s)\033[0m found : "
		BUNDLES_FOUND=$($($PARSING_CMD) | grep $ENTITY_TO_PARSE | awk -F "." '{print $3}' | tr '\n' ',' | sed 's/,$//')
		echo $BUNDLES_FOUND

		echo "  Generating content..."
		GENERATE_COUNT=20
		drush devel-generate-content $GENERATE_COUNT --types=$BUNDLES_FOUND

	else
		printf "- \033[1mNo CT bundle\033[0m found\n"
	fi

