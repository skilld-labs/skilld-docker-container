# skilld-docker-container

---

* [Overview](#overview)
* [Instructions](#instructions)
* [Usage](#usage)

## Overview


## Instructions

Supported PHP versions: 7.x and 5.6.x.

1\. Install docker for <a href="https://docs.docker.com/engine/installation/" target="_blank">Linux</a>, <a href="https://docs.docker.com/engine/installation/mac" target="_blank">Mac OS X</a> or <a href="https://docs.docker.com/engine/installation/windows" target="_blank">Windows</a>. __For Mac and Windows make sure you're installing native docker app version 1.12, not docker toolbox.__

For Linux install <a href="https://docs.docker.com/compose/install/" target="_blank">docker compose</a>

2\. Copy __\.env\.default__ to __\.env__

  2\.1\. Set _COMPOSE_PROJECT_NAME_, _PROFILE_NAME_, _THEME_NAME_ variables with values you need

  2\.2\. Change _PHP_IMAGE_ in case you need another one

  2\.3. List all libraries you need using _COMPOSER_REQUIRE_ variable and space as delimiter

3\. Copy __docker-compose\.override\.yml\.default__ to __docker-compose\.override\.yml__

  This file is used to overwrite container settings and/or add your own. See https://docs.docker.com/compose/extends/#/understanding-multiple-compose-files for details.

4\. Prepare your new Drupal site

  4\.1\. Check _drush_make_ folder

  4\.1\.1\. Change _*.make.yml_ and list your modules/profiles, etc

  4\.2\. Optionally rename _src/themes/projectname_theme_ to real project theme name

  4\.2\.1\. Setup your theme by renaming editing _projectname_theme.*_ files

  4\.3\. Optionally add you custom modules to _src/modules_

5\. Run `make`

Additional steps for MacOS install: (https://docs.docker.com/docker-for-mac/osxfs-caching/)

  2\.4\. Set SHARED_FOLDER variable to any writable absolute path instead of /dev/shm (PROJECT_PATH/sql for example)

3\. Copy __docker-compose\.override\.yml\.default_mac__ to __docker-compose\.override\.yml__

## Usage

* `make` - Install project.
* `make clean` - totally remove project build folder, docker containers and network.
* `make reinstall` - rebuild & reinstall site.
* `make si` - reinstall site.
* `make info` - Show project services IP addresses.
* `make chown` - Change permissions inside container. Use it in case you can not access files in _build_. folder from your machine.
* `make exec` - docker exec into php container.
* `make devel` - Devel + kint setup, and config for Twig debug mode.
* `make phpcs` - check codebase with `phpcs` sniffers to make sure it conforms https://www.drupal.org/docs/develop/standards.
* `make phpcbf` - fix codebase according to Drupal standards https://www.drupal.org/docs/develop/standards.
* `make cex` - executes config export to `config/sync` directory.
