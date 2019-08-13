#!/usr/bin/env sh

# Preparing
echo -e "Enabling module..."
drush pm:enable devel_generate -y

# Parsing command
PARSING_CMD='echo drush config:status --state=Any --format=list'

echo -e "\nLooking for bundles..."

# Voc entity

	# Entity to parse. Can be node.type or taxonomy.vocabulary for ex (see PARSING_CMD for more)
	ENTITY_TO_PARSE=taxonomy.vocabulary

	# Count bundles
	BUNDLE_COUNT=$($($PARSING_CMD) | grep -c $ENTITY_TO_PARSE)

	if [ "$BUNDLE_COUNT" -gt "0" ]; then

		printf "- \033[1m$BUNDLE_COUNT Voc bundle(s)\033[0m found : "
		BUNDLES_FOUND=$($($PARSING_CMD) | grep $ENTITY_TO_PARSE | awk -F "." '{print $3}' | tr '\n' ',' | sed 's/,$//')
		echo $BUNDLES_FOUND

		echo "  Generating content..."
		VOC_GENERATE_COUNT=10

		# TODO : Update after https://www.drupal.org/project/devel/issues/3073850
		BUNDLES_FOUND=$($($PARSING_CMD) | grep $ENTITY_TO_PARSE | awk -F "." '{print $3}')
		for voc_bundles in $BUNDLES_FOUND; do
			drush devel-generate-terms $voc_bundles $VOC_GENERATE_COUNT
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
		BUNDLES_FOUND=$($($PARSING_CMD) | grep $ENTITY_TO_PARSE | awk -F "." '{print $3}' | tr '\n' ',' | sed 's/,$//')
		echo $BUNDLES_FOUND

		echo "  Generating content..."
		CT_GENERATE_COUNT=100

		# TODO : Update after https://www.drupal.org/project/devel/issues/3073850
		BUNDLES_FOUND=$($($PARSING_CMD) | grep $ENTITY_TO_PARSE | awk -F "." '{print $3}')
		for ct_bundles in $BUNDLES_FOUND; do
			drush devel-generate-content $CT_GENERATE_COUNT --types=$ct_bundles --quiet
			echo "  $CT_GENERATE_COUNT nodes have been created for $ct_bundles"
		done

	else
		printf "- \033[1mNo CT bundle\033[0m found\n"
	fi


# Cleaning
echo -e "Disabling module..."
drush pmu devel_generate devel -y

# Informing
echo -e "\nRun this job multiple times for more content or enable Devel Generate in Drupal UI for manual creation."
