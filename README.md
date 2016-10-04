# skilld-docker-container

---

* [Overview](#overview)
* [Instructions](#instructions)
* [Usage](#usage)

## Overview


## Instructions

Supported PHP versions: 7.x and 5.6.x.

1\. Install docker for <a href="https://docs.docker.com/engine/installation/" target="_blank">Linux</a>, <a href="https://docs.docker.com/engine/installation/mac" target="_blank">Mac OS X</a> or <a href="https://docs.docker.com/engine/installation/windows" target="_blank">Windows</a>. __For Mac and Windows make sure you're installing native docker app version 1.12, not docker toolbox.__

For Linux additionally install <a href="https://docs.docker.com/compose/install/" target="_blank">docker compose</a>

2\. Copy __\.env\.default__ to __\.env__

  2\.1\. Set _COMPOSE_PROJECT_NAME_, _PROFILE_NAME_, _THEME_NAME_ variables with values you need
  
  2\.2\. Change _PHP_IMAGE_ in case you need another one
  
  2\.3. List all libraries you need using _COMPOSER_REQUIRE_ variable and space as delimiter
  
3\. Prepare your new Drupal site

  3\.1\. Check _drush_make_ folder
  
  3\.1\.1\. Change _*.make.yml_ and list your modules/profiles, etc
  
  3\.2\. Check _projectname_ folder
  
  3\.2\.1\. Rename _projectname_ folder to real project name
  
  3\.2\.2\. Rename and edit _projectname.info.yml_ and _projectname.install_
   
  3\.3\. Rename _projectname/projectname_theme_ to real project theme name
  
  3\.3\.1\. Setup your theme by renaming editing _projectname_theme.*_ files
  
4\. Run `make`

## Usage

* `make` - Install project.
* `make clean` - totally remove project build folder, docker containers and network.
* `make info` - Show info project IP.
* `make chown` - Change permissions inside container. Use it in case you can not access files in _build_. folder from your machine.
* `make exec` - docker exec into php container.
