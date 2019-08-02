# Add utility functions and scripts to the container
include scripts/makefile/*.mk

.PHONY: all provision si exec exec0 down clean dev drush info phpcs phpcbf hooksymlink clang cinsp compval watchdogval drupalcheckval behat sniffers tests front behatdl behatdi browser_driver browser_driver_stop statusreportval
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
# Define mysql storage folder.
MYSQL_DATADIR := $(DB_DATA_DIR)/$(COMPOSE_PROJECT_NAME)_mysql

# Execute php container as regular user
php = docker-compose exec -T --user $(CUID):$(CGID) php ${1}
# Execute php container as root user
php-0 = docker-compose exec -T php ${1}

## Full site install from the scratch
all: | provision composer si hooksymlink info

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
ifeq ($(shell docker-compose config --services | grep mysql),mysql)
	mkdir -p $(MYSQL_DATADIR)
endif
	make -s down
	@echo "Updating containers..."
	docker-compose pull
	@echo "Build and run containers..."
	docker-compose up -d --remove-orphans
	$(call php-0, apk add --no-cache graphicsmagick)
	$(call php-0, kill -USR2 1)
	$(call php, composer global require -o --update-no-dev --no-suggest "hirak/prestissimo:^0.3")

composer:
ifeq ($(INSTALL_DEV_DEPENDENCIES), TRUE)
	@echo "INSTALL_DEV_DEPENDENCIES=$(INSTALL_DEV_DEPENDENCIES)"
	@echo "Installing composer dependencies, including dev ones"
	$(call php, composer install --prefer-dist -o)
else
	@echo "INSTALL_DEV_DEPENDENCIES set to FALSE or missing from .env"
	@echo "Installing composer dependencies, without dev ones"
	$(call php, composer install --prefer-dist -o --no-dev)
endif
	$(call php, composer drupal-scaffold)
	$(call php, composer create-required-files)
#	Uncomment this string to build front separately. See scripts/makefile/front.mk
#	make -s front

## Install drupal
si:
	@echo "Installing from: $(PROJECT_INSTALL)"
ifeq ($(PROJECT_INSTALL), config)
	$(call php, sed -i 's/admin@example.com/$(ADMIN_MAIL)/g' web/profiles/sdd/config/install/update.settings.yml)
	$(call php, drush si config_installer --db-url=$(DB_URL) --account-name=$(ADMIN_NAME) --account-mail=$(ADMIN_MAIL) --account-pass=$(ADMIN_PW) -y config_installer_sync_configure_form.sync_directory=../config/sync)
else
	$(call php, drush si $(PROFILE_NAME) --db-url=$(DB_URL) --account-name=$(ADMIN_NAME) --account-mail=$(ADMIN_MAIL) --account-pass=$(ADMIN_PW) -y --site-name="$(SITE_NAME)" --site-mail="$(SITE_MAIL)" install_configure_form.site_default_country=FR install_configure_form.date_default_timezone=Europe/Paris)
endif
ifneq ($(strip $(MODULES)),)
	$(call php, drush en $(MODULES) -y)
	$(call php, drush pmu $(MODULES) -y)
endif

## Display project's information
info:
	$(info Containers for "$(COMPOSE_PROJECT_NAME)" info:)
	$(eval CONTAINERS = $(shell docker ps -f name=$(COMPOSE_PROJECT_NAME) --format "{{ .ID }}" -f 'label=traefik.enable=true'))
	$(foreach CONTAINER, $(CONTAINERS),$(info http://$(shell printf '%-19s \n'  $(shell docker inspect --format='{{(index .NetworkSettings.Networks "$(COMPOSE_NET_NAME)").IPAddress}}:{{index .Config.Labels "traefik.port"}} {{range $$p, $$conf := .NetworkSettings.Ports}}{{$$p}}{{end}} {{.Name}}' $(CONTAINER) | rev | sed "s/pct\//,pct:/g" | sed "s/,//" | rev | awk '{ print $0}')) ))
	@echo "$(RESULT)"
	@echo "UID1 - Login : \"$(ADMIN_NAME)\" - Password : \"$(ADMIN_PW)\""

## Run shell in PHP container as regular user
exec:
	docker-compose exec --user $(CUID):$(CGID) php ash

## Run shell in PHP container as root
exec0:
	docker-compose exec php ash

down:
	@echo "Removing network & containers for $(COMPOSE_PROJECT_NAME)"
	@docker-compose down -v --remove-orphans --rmi local
ifneq ($(shell docker ps -f 'name=$(COMPOSE_PROJECT_NAME)_chrome' --format '{{.Names}}'), )
	@echo 'Stoping browser driver.'
	make -s browser_driver_stop
endif

DIRS = web/core web/libraries web/modules/contrib web/profiles/contrib web/sites web/themes/contrib vendor

## Totally remove project build folder, docker containers and network
clean: info
ifneq ($(shell docker-compose ps -q php),'')
	$(eval SCAFFOLD = $(shell docker-compose exec -T --user $(CUID):$(CGID) php composer run-script list-scaffold-files | grep -P '^(?!>)'))
	@for i in $(SCAFFOLD); do if [ -e "web/$$i" ]; then echo "Removing web/$$i..."; rm -rf web/$$i; fi; done
endif
	make -s down
	@for i in $(DIRS); do if [ -d "$$i" ]; then echo "Removing $$i..."; docker run --rm -v $(shell pwd):/mnt $(IMAGE_PHP) sh -c "rm -rf /mnt/$$i"; fi; done
ifeq ($(shell docker-compose config --services | grep mysql),mysql)
	@if [ -d $(MYSQL_DATADIR) ]; then echo "Removing mysql data $(MYSQL_DATADIR) ..."; docker run --rm -v $(shell pwd):/mnt/2rm $(IMAGE_PHP) sh -c "rm -rf /mnt/2rm/$(DB_DATA_DIR)"; fi
endif

## Enable development mode and disable caching
dev:
	@echo "Dev tasks..."
	$(call php, composer install --prefer-dist -o)
	@$(call php-0, chmod +w web/sites/default)
	@$(call php, cp web/sites/default/default.services.yml web/sites/default/services.yml)
	@$(call php, sed -i -e 's/debug: false/debug: true/g' web/sites/default/services.yml)
	@$(call php, cp web/sites/example.settings.local.php web/sites/default/settings.local.php)
	@echo "Including settings.local.php."
	@$(call php-0, sed -i "/settings.local.php';/s/# //g" web/sites/default/settings.php)
	@$(call php, drush -y -q config-set system.performance css.preprocess 0)
	@$(call php, drush -y -q config-set system.performance js.preprocess 0)
	@echo "Enabling devel module."
	@$(call php, drush -y -q en devel devel_generate kint)
	@echo "Disabling caches."
	@$(call php, drush -y -q pm-uninstall dynamic_page_cache page_cache)
	@$(call php, drush cr)

## Run drush command in PHP container. To pass arguments use double dash: "make drush dl devel -- -y"
drush:
	$(call php, $(filter-out "$@",$(MAKECMDGOALS)))
	$(info "To pass arguments use double dash: "make drush dl devel -- -y"")

