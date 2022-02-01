.PHONY: all fast allfast provision si exec exec0 down clean dev drush info phpcs phpcbf hooksymlink clang cinsp compval watchdogval drupalrectorval upgradestatusval behat sniffers tests front front-install front-build clear-front lintval lint storybook back behatdl behatdi browser_driver browser_driver_stop statusreportval contentgen newlineeof localize local-settings redis-settings content patchval diff
.DEFAULT_GOAL := help

# https://stackoverflow.com/a/6273809/1826109
%:
	@:

# Prepare enviroment variables from defaults
$(shell false | cp -i \.env.default \.env 2>/dev/null)
include .env

# Select orchestrator related commands
# include Makefile_$(ORCHESTRATOR).mk
ifeq ($(ORCHESTRATOR), k3s)
include Makefile_k3s.mk
else
include Makefile_docker-compose.mk
endif

# Include utility functions and scripts
include scripts/makefile/*.mk

# Sanitize PROJECT_NAME input
COMPOSE_PROJECT_NAME := $(shell echo "$(PROJECT_NAME)" | tr -cd '[a-zA-Z0-9]' | tr '[:upper:]' '[:lower:]')

# Get user/group id to manage permissions between host and containers
LOCAL_UID := $(shell id -u)
LOCAL_GID := $(shell id -g)

# Evaluate recursively
CUID ?= $(LOCAL_UID)
CGID ?= $(LOCAL_GID)

# Determine database data directory if defined
DB_MOUNT_DIR=$(shell cd docker && realpath $(DB_DATA_DIR))/
ifeq ($(findstring mysql,$(SDC_SERVICES)),mysql)
	DB_MOUNT_DIR=$(shell cd docker && realpath $(DB_DATA_DIR))/$(COMPOSE_PROJECT_NAME)_mysql
endif
ifeq ($(findstring postgresql,$(SDC_SERVICES)),postgresql)
	DB_MOUNT_DIR=$(shell cd docker && realpath $(DB_DATA_DIR))/$(COMPOSE_PROJECT_NAME)_pgsql
endif

# Define current directory only once
CURDIR=$(shell pwd)

# Variables
ADDITIONAL_PHP_PACKAGES := tzdata graphicsmagick # php7-intl php7-redis wkhtmltopdf gnu-libiconv php7-pdo_pgsql postgresql-client postgresql-contrib
DC_MODULES := project_default_content better_normalizers default_content hal serialization
MG_MODULES := migrate_generator migrate migrate_plus migrate_source_csv migrate_tools


## Full site install from the scratch
all: | provision back front si localize hooksymlink info
# Install for CI deploy:review. Back & Front tasks are run in a dedicated previous step in order to leverage CI cache
all_ci: | provision si localize hooksymlink info
# Full site install from the scratch with DB in ram (makes data NOT persistant)
allfast: | fast

## Update .env to build DB in ram (makes data NOT persistant)
fast:
	$(shell sed -i "s|^#DB_URL=sqlite:///dev/shm/d8.sqlite|DB_URL=sqlite:///dev/shm/d8.sqlite|g"  .env)
	$(shell sed -i "s|^DB_URL=sqlite:./../.cache/d8.sqlite|#DB_URL=sqlite:./../.cache/d8.sqlite|g"  .env)
	$(info - Your .env file was updated. Run `make all` again.)
	exit 1

enforce-project-name:
ifeq ($(strip $(COMPOSE_PROJECT_NAME)),projectname)
	$(eval COMPOSE_PROJECT_NAME = $(strip $(shell read -p "Please enter project name: " REPLY;echo -n $$REPLY)))
	$(shell sed -i -e '/PROJECT_NAME=/ s/=.*/=$(COMPOSE_PROJECT_NAME)/' .env)
	$(info - Run `make all` again.)
	exit 1
endif

## Provision enviroment
provision:
# Check if enviroment variables has been defined
	make -s enforce-project-name
ifdef DB_MOUNT_DIR
	$(shell [ ! -d $(DB_MOUNT_DIR) ] && mkdir -p $(DB_MOUNT_DIR) && chmod 777 $(DB_MOUNT_DIR))
endif
	make -s down 2> /dev/null
	make -s install-orchestrator
	@echo "Build and run containers..."
	make -s up
	# Set composer2 as default
	$(call php-0, ln -fs composer2 /usr/bin/composer)
ifneq ($(strip $(ADDITIONAL_PHP_PACKAGES)),)
	$(call php-0, apk add --no-cache $(ADDITIONAL_PHP_PACKAGES))
endif
	# Set up timezone
	$(call php-0, cp /usr/share/zoneinfo/Europe/Paris /etc/localtime)
	# Install newrelic PHP extension if NEW_RELIC_LICENSE_KEY defined
	make -s newrelic
	$(call php-0, kill -USR2 1)

## Install backend dependencies
back:
ifneq ($(strip $(ADDITIONAL_PHP_PACKAGES)),)
	$(call php-0, apk add --no-cache $(ADDITIONAL_PHP_PACKAGES))
endif
	@echo "Installing composer dependencies, without dev ones"
	$(call php, composer install --no-interaction --prefer-dist -o --no-dev)
	$(call php, composer create-required-files)

$(eval TESTER_NAME := tester)
$(eval TESTER_ROLE := contributor)
## Install drupal
si:
	@echo "Installing from: $(PROJECT_INSTALL)"
ifeq ($(PROJECT_INSTALL), config)
	$(call php, drush si --existing-config --db-url="$(DB_URL)" --account-name="$(ADMIN_NAME)" --account-mail="$(ADMIN_MAIL)" -y)
	# install_import_translations() overwrites config translations so we need to reimport.
	$(call php, drush cim -y)
else
	$(call php, drush si $(PROFILE_NAME) --db-url="$(DB_URL)" --account-name="$(ADMIN_NAME)" --account-mail="$(ADMIN_MAIL)" -y --site-name="$(SITE_NAME)" --site-mail="$(SITE_MAIL)" install_configure_form.site_default_country=FR install_configure_form.date_default_timezone=Europe/Paris)
endif
	$(call php, drush user:create "$(TESTER_NAME)")
	$(call php, drush user:role:add "$(TESTER_ROLE)" "$(TESTER_NAME)")
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
	$(call php, drush migrate:import --all --group=mgg)
	$(call php, drush migrate_generator:clean_migrations mgg)
	$(call php, drush pmu $(MG_MODULES) -y)
endif

local-settings:
ifneq ("$(wildcard settings/settings.local.php)","")
	@echo "Turn on settings.local"
	$(call php, chmod +w web/sites/default)
	$(call php, cp settings/settings.local.php web/sites/default/settings.local.php)
	$(call php-0, sed -i "/settings.local.php';/s/# //g" web/sites/default/settings.php)
	$(call php, drush cr)
endif

redis-settings:
	REDIS_IS_INSTALLED := $(shell grep "redis.connection" web/sites/default/settings.php | tail -1 | wc -l || echo "0")
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
ifdef REVIEW_DOMAIN
	$(eval BASE_URL := $(MAIN_DOMAIN_NAME))
else
	$(eval BASE_URL := $(LOCAL_IP))
endif
ifeq ($(PROJECT_IS_UP), true)
	$(info )
	$(info Containers for "$(COMPOSE_PROJECT_NAME)":)
	$(info )
	$(info Login as System Admin: http://$(shell printf '%-19s \n'  $(shell echo "$(BASE_URL)"$(shell $(call php, drush user:login --name="$(ADMIN_NAME)" /admin/content/ | awk -F "default" '{print \$$2}')))))
	$(info Login as Contributor: http://$(shell printf '%-19s \n'  $(shell echo "$(BASE_URL)"$(shell $(call php, drush user:login --name="$(TESTER_NAME)" /admin/content/ | awk -F "default" '{print \$$2}')))))
endif
	$(info )
ifneq ($(shell diff .env .env.default -q),)
	@echo -e "\x1b[33mWARNING\x1b[0m - .env and .env.default files differ. Use 'make diff' to see details."
endif

## Output diff between local and versioned files
diff:
	diff -u0 --color .env .env.default || true; echo ""

#TODO: Redefine what is means to be upé
down:
ifeq ($(PROJECT_IS_UP), true)
	@echo "Removing network & containers for $(COMPOSE_PROJECT_NAME)"
	make -s down-containers
else
	@echo "No container to down"
endif
	make -s down-test-browser




## Totally remove project build folder, containers and network
clean:
	$(eval DIRS = web/core web/libraries web/modules/contrib web/profiles/contrib web/sites web/themes/contrib vendor)
	$(info Cleaning project "$(COMPOSE_PROJECT_NAME)"...)
	make -s down
	make -s scaffold-list
	$(eval RMLIST = $(addprefix web/,$(SCAFFOLD)) $(DIRS))
	for i in $(RMLIST); do rm -rf $$i && echo "Removed $$i"; done
ifdef DB_MOUNT_DIR
	@echo "Clean-up database data from $(DB_MOUNT_DIR) ..."
	$(shell rm -fr $(DB_MOUNT_DIR))
	#TODO: what was doccomp equivalent?
endif
ifeq ($(CLEAR_FRONT_PACKAGES), yes)
	make clear-front
endif
	make -s uninstall-orchestrator

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


## TODO: FIX TEST COMMANDS


check:
ifeq ($(PROJECT_IS_UP), true)
	@echo "Up"
else
	@echo "Down"
endif

