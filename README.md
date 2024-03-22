# Skilld docker container

---

- [Skilld docker container](#Skilld-docker-container)
  - [Overview](#Overview)
  - [What is this?](#What-is-this)
  - [What is this not?](#What-is-this-not)
  - [Quickstart](#Quickstart)
      - [Used variables](#Used-variables)
      - [Persistent Mysql](#Persistent-Mysql)
      - [Network](#Network)
  - [Usage](#Usage)
      - [Additional goals](#Additional-goals)
  - [Support](#Support)
  - [Drush commands](#Drush-commands)
  - [Troubleshooting](#Troubleshooting)
  - [Git hooks](#Git-hooks)
  - [License](#License)


## Overview

**Skilld docker container** is a developer starterkit for your Drupal project.

## What is this?

* This is a developer starterkit which can be used for local drupal development or/and integration into your CI/CD processes.

## What is this not?

* This is not `ready to use tool`, tools list you can find in <a href="https://docs.google.com/spreadsheets/d/11LWo_ks9TUoZIYJW0voXwogawohqAbOFv_dcBlAVs2E/edit#gid=0">this google doc</a>
* Another quick solution <a href="https://gist.github.com/andypost/f8e359f2e80cb7d4737350189f009646">https://gist.github.com/andypost/f8e359f2e80cb7d4737350189f009646</a>


## Quickstart

* Install docker for <a href="https://docs.docker.com/install/" target="_blank">Linux</a>, <a href="https://docs.docker.com/docker-for-mac/install/" target="_blank">Mac</a>, <a href="https://docs.docker.com/docker-for-windows/install/" target="_blank">Windows</a>
  *  Check <a href="https://docs.docker.com/install/linux/linux-postinstall/" target="_blank">post-installation steps for Linux</a> version 18.06.0 or later
* Install <a href="https://docs.docker.com/compose/install/" target="_blank">Docker Compose V2</a> version **2.0** or later

* Copy **.env.default** to **.env**, more information about enviroment file can be found <a href="https://docs.docker.com/compose/env-file/" target="_blank">docs.docker.com</a>
* Copy **docker-compose.override.yml.default** to **docker-compose.override.yml**, update parts you want to overwrite.
  * **docker-compose.yml** contains the base requirements of a working Drupal site. It should not be updated.
* Update **.gitlab-ci.yml** `variables` section THEME_PATH to make front gitlab CI works.
* Run `make all`


#### Used variables

| Variable name   | Description             | Default value |
| --------------- | ----------------------- | ------------- |
| COMPOSE_FILE   | Path to a Compose file(s) | `./docker/docker-compose.yml:./docker/docker-compose.override.yml` |
| COMPOSE_PROJECT_NAME   | Your project name | - |
| PROFILE_NAME   | Profile used for site install | druxxy |
| MODULES   | Additional modules to enable after site install | project_default_content |
| THEME_NAME  | Name of theme directory in /web/themes | `NA` |
| SITE_NAME  | Site name | Example |
| SITE_MAIL  | Site e-mail address | admin@example.com |
| ADMIN_NAME  | Admin username | admin |
| PROJECT_INSTALL | Way to install site - from straight or existing config | - |
| IMAGE_PHP | Php image to use | `skilldlabs/php:83-unit` |
| IMAGE_NGINX | Image to use for nginx container | `skilldlabs/nginx:1.24` |
| IMAGE_APACHE | Image to use for apache container | `skilldlabs/skilld-docker-apache` |
| IMAGE_FRONT | Image to use for front tasks | `skilldlabs/frontend:zen` |
| IMAGE_DRIVER | Image to use for automated testing webdriver | `zenika/alpine-chrome` |
| ADD_PHP_EXT | Additional php extension to install | - |
| MAIN_DOMAIN_NAME | Domain name used for traefik | `docker.localhost` |
| DB_URL | Url to connect to database | `sqlite:///dev/shm/db.sqlite` |
| DB_DATA_DIR | Full path to database storage | `/dev/shm` |
| CLEAR_FRONT_PACKAGES | Set it to `no` to keep `/node_nodules` directory in theme after `make front` task to save build time. | yes |
| RA_BASIC_AUTH | username:hashed-password format defining BasicAuth in Traefik. Password hashed using `htpasswd -nibB username password!` as [described here](https://doc.traefik.io/traefik/middlewares/basicauth/#general) | - |

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
    image: mysql:8.0-oraclelinux8
  ...
  ```
  * Update `.env` file, and set `DB_URL=mysql://db:db@mysql/db`

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
* `make diff` - Show changes in overrides (needs local `diff` command).
* `make exec` - `docker exec` into php container.
* `make exec0` - `docker exec` into php container as root.
* `make dev` - Devel + kint setup, and config for Twig debug mode, disable aggregation.
* `make drush [command]` - execute drush command.
* `make phpcs` - Check codebase with `phpcs` sniffers to make sure it conforms https://www.drupal.org/docs/develop/standards.
* `make phpcbf` - Fix codebase according to Drupal standards https://www.drupal.org/docs/develop/standards.
* `make front` - Builds frontend tasks.
* `make lint` - Runs frontend linters.
* `make storybook` - Runs storybook in current theme.
* `make blackfire` - Adds and enables blackfire.io php extension, needs [configuration](https://blackfire.io/docs/configuration/php) in docker-compose.override.yml.
* `make newrelic` - Adds and enables newrelic.com php extension, needs [configuration](https://docs.newrelic.com/docs/agents/php-agent/getting-started/introduction-new-relic-php#configuration) `NEW_RELIC_LICENSE_KEY` environment variable defined with valid license key.
* `make xdebug (on|off|status)` - Enable, disable or report status of [Xdebug](https://xdebug.org/docs/) PHP extension.

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
