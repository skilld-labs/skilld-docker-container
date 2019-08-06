# Skilld docker container

---

* [Overview](#overview)
* [What is this?](#what-is-this)
* [What is this not?](#what-is-this-not)
* [Quickstart](#quickstart)
  + [Used variables](#used-variables)
  + [Persistent Mysql](#persistent-mysql)
  + [Network](#network)
* [Usage](#usage)
  + [Additional goals](#additional-goals)
* [Support](#support)
* [Drush commands](#drush-commands)
* [Troubleshooting](#troubleshooting)
* [License](#license)


## Overview

**Skilld docker container** is a developer starterkit for your Drupal project.

## What is this?

* This is a developer starterkit which can be used for local drupal development or/and integration into your CI/CD processes.

## What is this not?

* This is not `ready to use tool`, tools list you can find in <a href="https://docs.google.com/spreadsheets/d/11LWo_ks9TUoZIYJW0voXwogawohqAbOFv_dcBlAVs2E/edit#gid=0">this google doc</a>
* Another quick solution <a href="https://gist.github.com/andypost/f8e359f2e80cb7d4737350189f009646">https://gist.github.com/andypost/f8e359f2e80cb7d4737350189f009646</a>


## Quickstart

* Install docker for <a href="https://docs.docker.com/install/" target="_blank">Linux</a>, <a href="https://docs.docker.com/docker-for-mac/install/" target="_blank">Mac</a>, <a href="https://docs.docker.com/docker-for-windows/install/" target="_blank">Windows</a>
  *  Check <a href="https://docs.docker.com/install/linux/linux-postinstall/" target="_blank">post-installation steps for Linux</a>
* Install <a href="https://docs.docker.com/compose/install/" target="_blank">docker compose</a>

* Copy **.env.default** to **.env**, more information about enviroment file can be found <a href="https://docs.docker.com/compose/env-file/" target="_blank">docs.docker.com</a>
* Copy **docker-compose.override.yml.default** to **docker-compose.override.yml**, update parts you want to overwrite.
  * **docker-compose.yml** contains the base requirements of a working Drupal site. It should not be updated.
* Run `make all`
 

#### Used variables

| Variable name   | Description             | Default value |
| --------------- | ----------------------- | ------------- |
| COMPOSE_FILE   | Path to a Compose file(s) | `./docker/docker-compose.yml:./docker/docker-compose.override.yml` |
| COMPOSE_PROJECT_NAME   | Your project name | - |
| PROFILE_NAME   | Profile used for site install | sdd |
| MODULES   | Additional modules to enable after site install | project_default_content |
| THEME_NAME  | Theme name used for frontend | - |
| SITE_NAME  | Site name | Example |
| SITE_MAIL  | Site e-mail address | admin@example.com |
| ADMIN_NAME  | Admin username | admin |
| ADMIN_PW  | Admin password | admin |
| ADMIN_MAIL  | Admin e-mail address | admin@example.com |
| PROJECT_INSTALL | Way to install site - from straight or existing config | - |
| IMAGE_PHP | Php image to use | `skilldlabs/php:72-fpm` |
| IMAGE_NGINX | Image to use for nginx container | `skilldlabs/nginx:1.14.1` |
| IMAGE_FRONT | Image to use for front tasks | `skilldlabs/frontend:zen` |
| IMAGE_DRIVER | Image to use for automated testing webdriver | `zenika/alpine-chrome` |
| MAIN_DOMAIN_NAME | Domain name used for traefik | `docker.localhost` |
| DB_URL | Url to connect to database | `sqlite:///dev/shm/d8.sqlite` |
| DB_DATA_DIR | Full path to database storage | `/dev/shm` |


#### Persistent Mysql

* By default sqlite storage used, which is created inside php container, if you need persistent data to be saved:
  * Update `docker-compose.override.yml`, set 
  ```yaml
  php:
     depends_on:
       - mysql
  ``` 
  and update mysql container part 
  ```yaml
  mysql:
    image: percona:5.7.22
  ...
  ``` 
  * Update `.env` file, and set `DB_URL=mysql://d8:d8@mysql/d8`

#### Network

* Every time project built, it take new available IP address, if you want to have persistent IP, uncomment lines from  `docker-compose.override.yml`
```yaml
networks:
  front:
    driver: bridge
    ipam:
      driver: default
      config:
        - subnet: "172.18.0.5"
```

## Usage

* `make` - Show this info.
* `make all` - Full project install from the scratch.
* `make clean` - Totally remove project build folder, files, docker containers and network.
* `make si` - Install/reinstall site.
* `make info` - Show project services IP addresses.
* `make exec` - `docker exec` into php container.
* `make exec0` - `docker exec` into php container as root.
* `make dev` - Devel + kint setup, and config for Twig debug mode, disable aggregation.
* `make drush [command]` - execute drush command. 
* `make phpcs` - Check codebase with `phpcs` sniffers to make sure it conforms https://www.drupal.org/docs/develop/standards.
* `make phpcbf` - Fix codebase according to Drupal standards https://www.drupal.org/docs/develop/standards.
* `make front` - Builds frontend tasks.
* `make lint` - Runs frontend linters.

#### Additional goals

* If you need to add your custom/specific project goal, create new file in `scripts/makefile/myfile.mk` and describe goal inside. Example can be found at <a href="scripts/makefile/backup.mk">`scripts/makefile/backup.mk`</a>

## Support

* This project is supported by <a href="http://www.skilld.fr">© Skilld SAS</a> 

## Drush commands

* You can run any drush command `make drush [command -- -argument]`

## Troubleshooting

* Use our <a href="https://github.com/skilld-labs/skilld-docker-container/issues">issue queue</a>, which is public, to search or add new issues.  

## Git hooks

* Project includes [git hooks](https://git-scm.com/book/en/v2/Customizing-Git-Git-Hooks) to perform automatic validation when certain git commands are executed
* You can bypass this validation with option `--no-verify`

## License

This project is licensed under the MIT open source license.
