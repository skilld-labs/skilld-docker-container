# Delivering script

## What

- This script deliver the current tag from a repo to another one using a Gitlab CI job, as part of continuous deployments
- You can also deliver to multiple repositories at the same time using multiple jobs in the same pipeline

## Why

Why not use the built-in mirroring functionality Gitlab-ci and other repository services usualy offer ?

- Because it doesn't work when your git repo is protected behind a basic authentication
- Because mirroring to multiple repos at once is sometime a premium (paid) feature
- Because artifacts (downloaded and generated files) are usualy not versioned in git

## Setup

2 files are required : 
- `.gitlab-ci.yml`
- `scripts/delivery-git/deliver_current_tag_via_git.sh`

1. Define a delivery CI job like "Deliver to repo XXX" in .gitlab-ci.yml, as shown in .gitlab-ci.delivery_example.yml
   - To include artefact dependencies, this CI job should be positioned after all dependencies have been built and installed and use the [dependencies](https://docs.gitlab.com/ee/ci/yaml/#dependencies) key word
1. In Gitlab UI, add the following custom CI/CD variables :
   - DELIVERY_REMOTE_REPO_IP : IP or domain name of target git repos
   - DELIVERY_REMOTE_REPO_PRIVATE_KEY : SSH private key matching public key added to git user
   - DELIVERY_REMOTE_REPO_TYPE : Possible values : "PLATFORM.SH" only for now, or leave empty if appropriate
   - DELIVERY_REMOTE_REPO_URL_1 : Git repo to which deliver current tag (you can have multiple ones)
   - DELIVERY_REMOTE_REPO_BRANCH : Git branch to which deliver current tag
   - GIT_USER_EMAIL : Email to be used by git user (used to commit)
   - GIT_USER_NAME : Name to be used by git user (used to commit)

