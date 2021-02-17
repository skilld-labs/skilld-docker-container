# Mirroring script

## What

- This script mirrors the current branch from a repo to another one using a Gitlab CI job
- You can also mirror to multiple repositories at the same time using multiple jobs in the same pipeline
- Additionally, branches non-existing in local repo are deleted from remote repo(s)

## Why

Why not use the built-in mirroring functionality Gitlab-ci and other repository services usualy offer ?

- Because it doesn't work when your git repo is protected behind a basic authentication
- Because mirroring to multiple repos at once is sometime a premium (paid) feature

## Setup

2 files are required : 
- `.gitlab-ci.yml`
- `mirror_current_branch.sh`

1. Define a mirroring CI job like "Mirror to repo XXX" in .gitlab-ci.yml, as shown in .gitlab-ci.mirroring_example.yml
1. In Gitlab UI, add the following custom CI/CD variables :
   - MIRRORING_REMOTE_REPO_IP : IP or domain name of target git repos
   - MIRRORING_REMOTE_REPO_PRIVATE_KEY : SSH private key matching public key added to git user
   - MIRRORING_REMOTE_REPO_TYPE : Possible values : "PLATFORM.SH" only for now, or leave empty if appropriate
   - MIRRORING_REMOTE_REPO_URL_1 : Git repo to which mirror current branch (you can have multiple ones)
   - GIT_USER_EMAIL : Email to be used by git user (used to commit)
   - GIT_USER_NAME : Name to be used by git user (used to commit)

