# Delivery via archive script

## What

- This script deliver the current tag from a repo to a raw file registry using a Gitlab CI job, as part of continuous deployments
- You can also deliver to multiple registries at the same time using multiple jobs in the same pipeline

## Why

- Because some hosters prefer to receive artifact archives for deployments
- Because artifacts (downloaded and generated files) are usualy not versioned in git

## Setup

2 files are required : 
- `.gitlab-ci.yml`

1. Define a delivery CI job like "Delivery 1" in .gitlab-ci.yml, as shown in .gitlab-ci.delivery_via_archive_example.yml
   - To include artefact dependencies, this CI job should be positioned after all dependencies have been built and installed and use the [dependencies](https://docs.gitlab.com/ee/ci/yaml/#dependencies) key word
1. In Gitlab UI, add the following custom CI/CD variables :
   - DELIVERY_REPOSITORIES_RAW_REGISTRY_DOMAIN_1 : Docker repository to which deliver current tag (you can have multiple ones)
   - DELIVERY_REPOSITORIES_USERNAME : Service account credentials to use to push Docker image
   - DELIVERY_REPOSITORIES_PASSWORD : Service account credentials to use to push Docker image

