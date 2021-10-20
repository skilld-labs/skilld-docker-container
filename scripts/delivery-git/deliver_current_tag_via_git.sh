#!/usr/bin/env sh
# Use with Gitlab CI jobs from scripts/delivery/.gitlab-ci.delivery_example.yml

echo -e "\n- Start of delivery script"
# set -x #echo on

# Defining functions # For local use only, NOT FOR USE IN CI

CURRENT_TAG_FUNC()
	{
		git describe --tags $(git rev-list --tags --max-count=1)
	}

# Defining variables
echo -e "- Defining variables...\n"

PACKAGE_DIR=$(pwd)/files_to_be_deployed
echo -e "PACKAGE_DIR = $PACKAGE_DIR"

# TARGET_GIT_REPO=XXX@XXX.git # For local use only, NOT FOR USE IN CI
# For CI use, var is moved to CI job itself, so that same script can be used to clone on multiple repos
echo -e "TARGET_GIT_REPO = $TARGET_GIT_REPO"

# TARGET_GIT_REPO_BRANCH=master # For local use only, NOT FOR USE IN CI
# For CI use, var is moved to CI job itself, so that same script can be used to clone on multiple repos
echo -e "TARGET_GIT_REPO_BRANCH = $TARGET_GIT_REPO_BRANCH"

# TARGET_GIT_REPO_TYPE=GITLAB # For local use only, NOT FOR USE IN CI
# For CI use, var is moved to CI job itself, so that same script can be used to clone on multiple repos
echo -e "TARGET_GIT_REPO_TYPE = $TARGET_GIT_REPO_TYPE"

# CURRENT_TAG=$(CURRENT_TAG_FUNC) # For local use only, NOT FOR USE IN CI
CURRENT_TAG="$CI_COMMIT_REF_NAME" # For CI use only, using Gitlab predefined variable
echo -e "CURRENT_TAG = $CURRENT_TAG"

# GIT_USER_EMAIL="XXX@XXX.com" # For local use only, NOT FOR USE IN CI
echo -e "GIT_USER_EMAIL = $GIT_USER_EMAIL" # For CI use only, using Gitlab custom variable

# GIT_USER_NAME="XXX CI/CD" # For local use only, NOT FOR USE IN CI
echo -e "GIT_USER_NAME = $GIT_USER_NAME" # For CI use only, using Gitlab custom variable

# Preparing delivery dir
echo -e "- Preparing delivery dir...\n"
mkdir "$PACKAGE_DIR"
cd "$PACKAGE_DIR"

# Initialising external git repo
echo -e "- Initialising external git repo...\n"
git init && git config --local core.excludesfile false && git config --local core.fileMode true
git remote add origin $TARGET_GIT_REPO
git pull origin master
git fetch
git checkout $TARGET_GIT_REPO_BRANCH
git config --local user.email "$GIT_USER_EMAIL"
git config --local user.name "$GIT_USER_NAME"

# Deleting files in delivery dir
echo -e "- Deleting files in delivery dir...\n"
set -x #echo on
find -maxdepth 1 ! -name '.git' -exec rm -rv {} \; 1> /dev/null
ls -lah

# Copying files to delivery dir
echo -e "- Copying files to delivery dir...\n"
rsync -av --quiet --progress ../. . --exclude .git/ --exclude files_to_be_deployed/

# Making sure everything needed will be included in commit
echo -e "- Making sure everything needed will be included in commit...\n"
echo -e "-- Deleting all .gitignore files...\n"
mv .gitignore .gitig
find . -name '.gitignore' -type f | wc -l
find . -name '.gitignore' -type f -exec rm {} +
# mv .gitig .gitignore // Note that we don't keep the .gitignore file like we usualy do, all project content must be commited here

echo -e "-- Deleting all .git directories except root one...\n"
mv .git .got
find . -name '.git' -type d | wc -l
find . -name '.git' -type d -exec rm -rf {} +
mv .got .git

# Removing local DB settings from settings.php
sed -i -e "/$databases\['default'\]\['default'\] = array (/,/)/d" web/sites/default/settings.php
# Adding install profile value in settings.php
echo "\$settings['install_profile'] = 'druxxy';" >> web/sites/default/settings.php
# Adding settings.local.php to web dir
cp settings/settings.local.php web/sites/default/settings.local.php
sed -i "/settings.local.php';/s/# //g" web/sites/default/settings.php

# Preventing platform.sh error "Application name 'app' is not unique"
if [ "$TARGET_GIT_REPO_TYPE" = "PLATFORM.SH" ]; then
	echo -e "- Preventing platform.sh error "Application name 'app' is not unique"...\n"
	sed -i "s|name: 'app'|name: 'XXX'|g" ../.platform.app.yaml
fi
# Moving hosting env files back at project root
if [ "$TARGET_GIT_REPO_TYPE" = "GITLAB" ]; then
	echo -e "- Moving hosting env files back at project root...\n"
	mv .gitlab-ci.yml .gitlab-ci-backup.yml
	mv hosting/* hosting/.* .
fi

# Commiting to external repo
echo -e "- Commiting to external repo...\n"
git add -A 1> /dev/null
git status -s
git commit --quiet -m "$CURRENT_TAG"
git push origin $TARGET_GIT_REPO_BRANCH --quiet
git tag "$CURRENT_TAG"
git push --tag

# Cleaning delivery dir
echo -e "- Cleaning delivery dir...\n"
cd ..
rm -rf "$PACKAGE_DIR"

echo -e "- End of delivery script"

