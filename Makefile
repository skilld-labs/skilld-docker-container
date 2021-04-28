# Add utility functions and scripts to the container
include scripts/makefile/*.mk

.PHONY: all fast allfast provision si exec exec0 down clean dev drush info phpcs phpcbf hooksymlink clang cinsp compval watchdogval drupalrectorval upgradestatusval behat sniffers tests front front-install front-build clear-front lintval lint storybook back behatdl behatdi browser_driver browser_driver_stop statusreportval contentgen newlineeof localize local-settings redis-settings content hookupdateval patchval diff
.DEFAULT_GOAL := help

# https://stackoverflow.com/a/6273809/1826109
%:
	@:

# Prepare enviroment variables from defaults
$(shell false | cp -i \.env.default \.env 2>/dev/null)
$(shell false | cp -i \.\/docker\/docker-compose\.override\.yml\.default \.\/docker\/docker-compose\.override\.yml 2>/dev/null)
include .env

# Get user/group id to manage permissions between host and containers
LOCAL_UID := $(shell id -u)
LOCAL_GID := $(shell id -g)

# Evaluate recursively
CUID ?= $(LOCAL_UID)
CGID ?= $(LOCAL_GID)

# Define network name.
COMPOSE_NET_NAME := $(COMPOSE_PROJECT_NAME)_front

SDC_SERVICES=$(shell docker-compose config --services)
# Determine database data directory if defined
ifeq ($(findstring mysql,$(SDC_SERVICES)),mysql)
	DB_MOUNT_DIR=$(shell cd docker && realpath $(DB_DATA_DIR))/$(COMPOSE_PROJECT_NAME)_mysql
endif
ifeq ($(findstring postgresql,$(SDC_SERVICES)),postgresql)
	DB_MOUNT_DIR=$(shell cd docker && realpath $(DB_DATA_DIR))/$(COMPOSE_PROJECT_NAME)_pgsql
endif

# Define current directory only once
CURDIR=$(shell pwd)

# Execute php container as regular user
php = docker-compose exec -T --user $(CUID):$(CGID) php ${1}
# Execute php container as root user
php-0 = docker-compose exec -T --user 0:0 php ${1}

## Full site install from the scratch
all: | provision back front si localize hooksymlink info
# Install for CI deploy:review. Back & Front tasks are run in a dedicated previous step in order to leverage CI cache
all_ci: | provision si localize hooksymlink info
# Full site install from the scratch with DB in ram (makes data NOT persistant)
allfast: | fast provision back front si localize hooksymlink info

## Update .env to build DB in ram (makes data NOT persistant)
fast:
	$(shell sed -i "s|^#DB_URL=sqlite:///dev/shm/d8.sqlite|DB_URL=sqlite:///dev/shm/d8.sqlite|g"  .env)
	$(shell sed -i "s|^DB_URL=sqlite:./../.cache/d8.sqlite|#DB_URL=sqlite:./../.cache/d8.sqlite|g"  .env)

## Provision enviroment
provision:
# Check if enviroment variables has been defined
ifeq ($(strip $(COMPOSE_PROJECT_NAME)),projectname)
	$(info Project name can not be default, please enter project name.)
	$(eval COMPOSE_PROJECT_NAME = $(strip $(shell read -p "Project name: " REPLY;echo -n $$REPLY)))
	$(shell sed -i -e '/COMPOSE_PROJECT_NAME=/ s/=.*/=$(COMPOSE_PROJECT_NAME)/' .env)
	$(info Please review your project settings and run `make all` again.)
	exit 1
endif
ifdef DB_MOUNT_DIR
	$(shell [ ! -d $(DB_MOUNT_DIR) ] && mkdir -p $(DB_MOUNT_DIR) && chmod 777 $(DB_MOUNT_DIR))
endif
	make -s down
	@echo "Build and run containers..."
	docker-compose up -d --remove-orphans
	# Set composer2 as default
	$(call php-0, ln -fs composer2 /usr/bin/composer)
	$(call php-0, apk add --no-cache tzdata $(ADD_PHP_EXT))
	# Set up timezone
	$(call php-0, cp /usr/share/zoneinfo/Europe/Paris /etc/localtime)
	# Install newrelic PHP extension if NEW_RELIC_LICENSE_KEY defined
	make -s newrelic
	$(call php-0, kill -USR2 1)

## Install backend dependencies
back:
	docker-compose up -d --remove-orphans --no-deps php # PHP container is required for composer
	# Set composer2 as default
	$(call php-0, ln -fs composer2 /usr/bin/composer)
ifneq ($(strip $(ADD_PHP_EXT)),)
# Install additional php extensions as this goal used in CI (todo stop doing it)
	$(call php-0, apk add --no-cache $(ADD_PHP_EXT))
endif
ifeq ($(INSTALL_DEV_DEPENDENCIES), TRUE)
	@echo "INSTALL_DEV_DEPENDENCIES=$(INSTALL_DEV_DEPENDENCIES)"
	@echo "Installing composer dependencies, including dev ones"
	$(call php, composer install --no-interaction --prefer-dist -o)
else
	@echo "INSTALL_DEV_DEPENDENCIES set to FALSE or missing from .env"
	@echo "Installing composer dependencies, without dev ones"
	$(call php, composer install --no-interaction --prefer-dist -o --no-dev)
endif
	$(call php, composer create-required-files)

$(eval TESTER_NAME := tester)
$(eval TESTER_ROLE := contributor)
## Install drupal
si:
	@echo "Installing from: $(PROJECT_INSTALL)"
ifeq ($(PROJECT_INSTALL), config)
	$(call php, drush si --existing-config --db-url="$(DB_URL)" --account-name="$(ADMIN_NAME)" --account-mail="$(ADMIN_MAIL)" --account-pass="$(ADMIN_PW)" -y)
	# install_import_translations() overwrites config translations so we need to reimport.
	$(call php, drush cim -y)
else
	$(call php, drush si $(PROFILE_NAME) --db-url="$(DB_URL)" --account-name="$(ADMIN_NAME)" --account-mail="$(ADMIN_MAIL)" --account-pass="$(ADMIN_PW)" -y --site-name="$(SITE_NAME)" --site-mail="$(SITE_MAIL)" install_configure_form.site_default_country=FR install_configure_form.date_default_timezone=Europe/Paris)
endif
	$(call php, drush user:create "$(TESTER_NAME)")
	$(call php, drush user:role:add "$(TESTER_ROLE)" "$(TESTER_NAME)")
	$(call php, drush user:password "$(TESTER_NAME)" "$(TESTER_PW)")
	make content
	make -s local-settings
	#make -s redis-settings

content:
ifneq ($(strip $(DC_MODULES)),)
	$(call php, drush en $(DC_MODULES) -y)
	$(call php, drush pmu $(DC_MODULES) -y)
endif
ifneq ($(strip $(MG_MODULES)),)
	$(call php, drush en $(MG_MODULES) -y)
	$(call php, drush migrate_generator:generate_migrations /var/www/html/content --update)
	$(call php, drush migrate:import --all --group=migrate_generator_group)
	$(call php, drush pmu $(MG_MODULES) -y)
	@echo "Deleting configs created by migrate_generator..." # https://dgo.to/3205125
	for i in $(shell docker-compose exec --user $(CUID):$(CGID) php drush config:status --state=Any --format=list | grep -E 'migrate_plus.migration.migrate_generator|migrate_plus.migration_group.migrate_generator_group') ; do $(call php, drush config:delete -y $$i) ; done
endif

local-settings:
ifneq ("$(wildcard settings/settings.local.php)","")
	@echo "Turn on settings.local"
	$(call php, chmod +w web/sites/default)
	$(call php, cp settings/settings.local.php web/sites/default/settings.local.php)
	$(call php-0, sed -i "/settings.local.php';/s/# //g" web/sites/default/settings.php)
	$(call php, drush cr)
endif

REDIS_IS_INSTALLED := $(shell grep "redis.connection" web/sites/default/settings.php | tail -1 | wc -l || echo "0")
redis-settings:
ifeq ($(REDIS_IS_INSTALLED), 1)
	@echo "Redis settings already installed, nothing to do"
else
	@echo "Turn on Redis settings"
	$(call php-0, chmod -R +w web/sites/)
	$(call php, cat settings/settings.redis.php >> web/sites/default/settings.php)
endif

## Import online & local translations
localize:
	@echo "Checking & importing online translations..."
	$(call php, drush locale:check)
	$(call php, drush locale:update)
	@echo "Importing custom translations..."
	$(call php, drush locale:import:all /var/www/html/translations/ --type=customized --override=all)
	@echo "Localization finished"

## Display project's information
info:
	$(info Containers for "$(COMPOSE_PROJECT_NAME)" info:)
	$(eval CONTAINERS = $(shell docker ps -f name=$(COMPOSE_PROJECT_NAME) --format "{{ .ID }}" -f 'label=traefik.enable=true'))
	$(foreach CONTAINER, $(CONTAINERS),$(info http://$(shell printf '%-19s \n'  $(shell docker inspect --format='{{(index .NetworkSettings.Networks "$(COMPOSE_NET_NAME)").IPAddress}}:{{index .Config.Labels "traefik.port"}} {{range $$p, $$conf := .NetworkSettings.Ports}}{{$$p}}{{end}} {{.Name}}' $(CONTAINER) | rev | sed "s/pct\//,pct:/g" | sed "s/,//" | rev | awk '{ print $0}')) ))
	@echo "$(RESULT)"
	@echo -e "System admin role - Login : \"$(ADMIN_NAME)\" - Password : \"$(ADMIN_PW)\""
	@echo -e "Contributor role - Login : \"$(TESTER_NAME)\" - Password : \"$(TESTER_PW)\"\n"
ifneq ($(shell diff .env .env.default -q),)
	@echo -e "\x1b[33mWARNING\x1b[0m - .env and .env.default files differ. Use 'make diff' to see details."
endif
ifneq ($(shell diff docker/docker-compose.override.yml docker/docker-compose.override.yml.default -q),)
	@echo -e "\x1b[33mWARNING\x1b[0m - docker/docker-compose.override.yml and docker/docker-compose.override.yml.default files differ. Use 'make diff' to see details."
endif

## Output diff between local and versioned files
diff:
	diff --color .env .env.default || true; echo ""
	diff --color docker/docker-compose.override.yml docker/docker-compose.override.yml.default || true; echo ""


## Run shell in PHP container as regular user
exec:
	docker-compose exec --user $(CUID):$(CGID) php ash

## Run shell in PHP container as root
exec0:
	docker-compose exec --user 0:0 php ash

down:
	@echo "Removing network & containers for $(COMPOSE_PROJECT_NAME)"
	@docker-compose down -v --remove-orphans --rmi local
	@if [ ! -z "$(shell docker ps -f 'name=$(COMPOSE_PROJECT_NAME)_chrome' --format '{{.Names}}')" ]; then \
		echo 'Stoping browser driver.' && make -s browser_driver_stop; fi

DIRS = web/core web/libraries web/modules/contrib web/profiles/contrib web/sites web/themes/contrib vendor

## Totally remove project build folder, docker containers and network
clean: info
	make -s down
	$(eval SCAFFOLD = $(shell docker run --rm -v $(CURDIR):/mnt -w /mnt --user $(CUID):$(CGID) $(IMAGE_PHP) composer run-script list-scaffold-files | grep -P '^(?!>)'))
	@docker run --rm --user 0:0 -v $(CURDIR):/mnt -w /mnt -e RMLIST="$(addprefix web/,$(SCAFFOLD)) $(DIRS)" $(IMAGE_PHP) sh -c 'for i in $$RMLIST; do rm -fr $$i && echo "Removed $$i"; done'
ifdef DB_MOUNT_DIR
	@echo "Clean-up database data from $(DB_MOUNT_DIR) ..."
	docker run --rm --user 0:0 -v $(shell dirname $(DB_MOUNT_DIR)):/mnt $(IMAGE_PHP) sh -c "rm -fr /mnt/`basename $(DB_MOUNT_DIR)`"
endif
ifeq ($(CLEAR_FRONT_PACKAGES), yes)
	make clear-front
endif

## Enable development mode and disable caching
dev:
	@echo "Dev tasks..."
	$(call php, composer install --no-interaction --prefer-dist -o)
	@$(call php-0, chmod +w web/sites/default)
	@$(call php, cp web/sites/default/default.services.yml web/sites/default/services.yml)
	@$(call php, sed -i -e 's/debug: false/debug: true/g' web/sites/default/services.yml)
	@$(call php, cp web/sites/example.settings.local.php web/sites/default/settings.local.php)
	@echo "Including settings.local.php."
	@$(call php-0, sed -i "/settings.local.php';/s/# //g" web/sites/default/settings.php)
	@$(call php, drush -y -q config-set system.performance css.preprocess 0)
	@$(call php, drush -y -q config-set system.performance js.preprocess 0)
	@echo "Enabling devel module."
	@$(call php, drush -y -q en devel devel_generate)
	@echo "Disabling caches."
	@$(call php, drush -y -q pm-uninstall dynamic_page_cache page_cache)
	@$(call php, drush cr)

## Run drush command in PHP container. To pass arguments use double dash: "make drush dl devel -- -y"
drush:
	$(call php, $(filter-out "$@",$(MAKECMDGOALS)))
	$(info "To pass arguments use double dash: "make drush en devel -- -y"")
