# Multisite script

## What

- These are scripts and commands to facilitate the use of different set of config in a multisite setup
- It can be used locally using make commands as well as in Gitalb CI/CD pipelines using manual jobs 

## Why

- Being able to quickly switch from one set of config to another is very much useful for testing on a multisite Drupal setup

## Setup

3 files are required : 
- `.gitlab-ci.yml`
- `config_split.mk`
- `config_split_disable_all.sh`

1. Install and enable config_split module :
   - `composer require drupal/config_split`
   - `drush en -y config_split`
1. In Drupal UI, create split(s) for site where config vary
   - Do not create a split for "default" case, in which all shared config should be stored
1. Create the config directories required by created splits
1. Define a CI job "Enable split default" in .gitlab-ci.yml, as shown in .gitlab-ci.mirroring_example.yml
1. Define additional CI jobs like "Enable split first" in .gitlab-ci.yml for each split
1. Move files to scripts/makefile/ directory :
   - `mv scripts/multisite/config_split.mk scripts/makefile/`
   - `mv scripts/multisite/config_split_disable_all.sh scripts/makefile/`

## Usage

Locally you can use commands like :
- `make split first` to simulate site "first" of multisite
- `make split default` to revert back to no split

On Gitlab CI/CD, Review Apps will be builded using default split :
- Manually click on manual jobs "Enable split first" to simulate site "first" of multisite
- Manually click on manual job "Enable split default" to revert back to no split

