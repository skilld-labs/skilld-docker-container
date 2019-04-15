#!/usr/bin/env sh
# curl and rm command should be removed in favor of composer when https://github.com/mglaman/drupal-check/issues/38 is fixed

# Get latest release version url
LATEST_RELEASE_VERSION_URL=$(curl --silent "https://api.github.com/repos/mglaman/drupal-check/releases/latest" | grep "browser_download_url" | sed -E 's/.*"([^"]+)".*/\1/')

# Define directory to scan recursively
DIRECTORY_TO_SCAN="web/modules/custom/"

# Get command result count
COMMAND_COUNT=$(curl -s -O -L $LATEST_RELEASE_VERSION_URL \
    && chmod +x drupal-check.phar \
    && ./drupal-check.phar -ad -vv -n --no-progress $DIRECTORY_TO_SCAN --format=raw | wc -l)

# Exit1 and alert if not ok, otherwise remain silent
if [[ "$COMMAND_COUNT" -gt "0" ]]; then
	printf "The are \033[1m$COMMAND_COUNT issues\033[0m detected by drupal-check to fix :\n"
	./drupal-check.phar -ad -vv -n --no-progress $DIRECTORY_TO_SCAN
	rm drupal-check.phar
	exit 1
else
	rm drupal-check.phar
	exit 0
fi
