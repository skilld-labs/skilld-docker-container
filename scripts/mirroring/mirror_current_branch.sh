#!/usr/bin/env sh
# Use with Gitlab CI jobs from scripts/mirroring/.gitlab-ci.mirroring_example.yml
set -x
echo -e "\n- Start of mirroring script"

# Defining functions # For local use only, NOT FOR USE IN CI

CURRENT_BRANCH_FUNC()
	{
		git rev-parse --abbrev-ref HEAD
	}


CURRENT_COMMIT_FUNC()
	{
		git log -1 --pretty=%B
	}

# Defining variables
echo -e "- Defining variables...\n"

MIRRORING_DIR=$(pwd)/files_to_mirror
echo -e "MIRRORING_DIR = $MIRRORING_DIR"

# MIRRORING_TARGET_GIT_REPO=XXX@XXX.git # For local use only, NOT FOR USE IN CI
# For CI use, var is moved to CI job itself, so that same script can be used to clone on multiple repos
echo -e "MIRRORING_TARGET_GIT_REPO = $MIRRORING_TARGET_GIT_REPO"

# CURRENT_BRANCH=$(CURRENT_BRANCH_FUNC) # For local use only, NOT FOR USE IN CI
CURRENT_BRANCH="$CI_COMMIT_REF_NAME" # For CI use only, using Gitlab predefined variable
echo -e "CURRENT_BRANCH = $CURRENT_BRANCH"

# CURRENT_COMMIT=$(CURRENT_COMMIT_FUNC) # For local use only, NOT FOR USE IN CI
CURRENT_COMMIT="$CI_COMMIT_MESSAGE" # For CI use only, using Gitlab predefined variable
echo -e "CURRENT_COMMIT = $CURRENT_COMMIT"

# GIT_USER_EMAIL="XXX@XXX.com" # For local use only, NOT FOR USE IN CI
echo -e "GIT_USER_EMAIL = $GIT_USER_EMAIL" # For CI use only, using Gitlab custom variable

# GIT_USER_NAME="XXX CI/CD" # For local use only, NOT FOR USE IN CI
echo -e "GIT_USER_NAME = $GIT_USER_NAME" # For CI use only, using Gitlab custom variable

# Saving list of branches in GitLab before switching directory
echo -e "- Fetching branches of current repo...\n"
git fetch --quiet 1> /dev/null
LOCAL_BRANCHES=$(git branch -r)

# Preparing mirrorring dir
echo -e "- Preparing mirrorring dir...\n"
mkdir "$MIRRORING_DIR"
cd "$MIRRORING_DIR"

# Initialising external git repo
echo -e "- Initialising external git repo...\n"
git init && git config --local core.excludesfile false && git config --local core.fileMode true
git remote add origin $MIRRORING_TARGET_GIT_REPO
git fetch origin
git checkout -b $CURRENT_BRANCH
git config --local user.email "$GIT_USER_EMAIL"
git config --local user.name "$GIT_USER_NAME"


# Cleaninng orphan branches in remote repo, compared to local repo
echo -e "- Syncing git branches..."
REMOTE_BRANCHES=$(git branch -r)
REMOVED_BRANCHES=$(echo "$REMOTE_BRANCHES" | grep -v "$(echo "$LOCAL_BRANCHES" | sed ':a;N;$!ba;s/\n/\\|/g')" | sed 's/origin\///g;s/\n/ /g')

if [ ! -z "$REMOVED_BRANCHES" ]
then
	echo -e "- Removing branches from remote git repo :"
	echo -e "$REMOVED_BRANCHES"
	if [ "$MIRRORING_REMOTE_REPO_TYPE" -eq "PLATFORM.SH" ]; then
		echo -e "Use platform.sh CLI to remove environments along with git branches"
		curl -sS https://platform.sh/cli/installer | php
		"$HOME/"'.platformsh/bin/platform' environment:delete --delete-branch -y $REMOVED_BRANCHES
	else
		echo -e "Use git to remove branches"
		git branch -D $REMOVED_BRANCHES
		git push origin --delete $REMOVED_BRANCHES
	fi
fi


# Copying files to mirrorring dir
echo -e "- Copying files to mirrorring dir...\n"
rsync -av --quiet --progress ../. . --exclude .git/ --exclude files_to_mirror/


# Making sure everything needed will be included in commit
echo -e "- Making sure everything needed will be included in commit...\n"
mv .gitignore .gitig
echo -e "- Deleting all .gitignore files except root one...\n"
find . -name '.gitignore' -type f | wc -l
find . -name '.gitignore' -type f -exec rm {} +
mv .gitig .gitignore

echo -e "- Deleting all .git directories except root one...\n"
mv .git .got
find . -name '.git' -type d | wc -l
find . -name '.git' -type d -exec rm -rf {} +
mv .got .git


# Preventing platform.sh error "Application name 'app' is not unique"
if [ "$MIRRORING_REMOTE_REPO_TYPE" -eq "PLATFORM.SH" ]; then
	echo -e "- Preventing platform.sh error "Application name 'app' is not unique"...\n"
	sed -i "s|name: 'app'|name: 'XXX'|g" ../.platform.app.yaml
fi


# Commiting to external repo
echo -e "- Commiting to external repo...\n"
git add -A 1> /dev/null
git status -s
git commit --quiet -m "$CURRENT_COMMIT"
git push origin $CURRENT_BRANCH --quiet -f


# Cleaning mirrorring dir
echo -e "- Cleaning mirrorring dir...\n"
cd ..
rm -rf "$MIRRORING_DIR"

echo -e "- End of mirroring script"
