.PHONY: all up down cex cim prepare install si exec info phpcs phpcbf

# Read project name from .env file
$(shell cp -n \.env.default \.env)
$(shell cp -n \.\/docker\/docker-compose\.override\.yml\.default \.\/docker\/docker-compose\.override\.yml)
include .env

# Get local values only once.
LOCAL_UID := $(shell id -u)
LOCAL_GID := $(shell id -g)

# Evaluate recursively.
CUID ?= $(LOCAL_UID)
CGID ?= $(LOCAL_GID)

# Prepare network name https://github.com/docker/compose/issues/2923
COMPOSE_NET_NAME := $(shell echo $(COMPOSE_PROJECT_NAME) | tr '[:upper:]' '[:lower:]'| sed -E 's/[^a-z0-9]+//g')_front

php = docker-compose exec -T --user $(CUID):$(CGID) php time ${1}
php-0 = docker-compose exec -T php time ${1}
front = docker run --rm -u $(CUID):$(CGID) -v $(shell pwd)/web/themes/$(THEME_NAME):/work $(IMAGE_FRONT) ${1}

all: | include prepare install si info

include:
ifeq ($(strip $(COMPOSE_PROJECT_NAME)),projectname)
#todo: ask user to make a project name and mv folders.
$(error Project name can not be default, please edit ".env" and set COMPOSE_PROJECT_NAME variable.)
endif

prepare:
	mkdir -p /dev/shm/${COMPOSE_PROJECT_NAME}_mysql
	make -s down
	make -s up
	$(call php-0, apk add --no-cache --repository http://dl-cdn.alpinelinux.org/alpine/edge/community git)
	$(call php-0, kill -USR2 1)
	$(call php, composer global require -o --update-no-dev --no-suggest "hirak/prestissimo:^0.3")

install:
	$(call php, composer install --prefer-dist -o --no-dev)
	$(call php, composer drupal-scaffold)

si:
	$(call php-0, chmod +w web/sites/default)
ifneq ("$(wildcard web/sites/default/settings.php)","")
	$(call php-0, rm -f web/sites/default/settings.php)
endif
	@echo "Installing from: $(PROJECT_INSTALL)"
ifeq ($(PROJECT_INSTALL), config)
	$(call php, drush si config_installer --db-url=$(DB_URL) --account-pass=admin -y config_installer_sync_configure_form.sync_directory=../config/sync)
else
	$(call php, drush si $(PROFILE_NAME) --db-url=$(DB_URL) --account-pass=admin -y --site-name="$(SITE_NAME)" --site-mail="$(SITE_MAIL)" install_configure_form.site_default_country=FR install_configure_form.date_default_timezone=Europe/Paris)
endif
	#$(call php, drush en $(MODULES) -y)
	#$(call php, drush pmu $(MODULES) -y)
	#make -s locale-update
	#make -s cim
	#make -s update-alias
	#make -s _local-settings
	#make -s info

locale-update:
	$(call php, drush locale-check)
	$(call php, drush locale-update)

_local-settings:
	@echo "Turn on settings.local"
	$(call php, chmod +w web/sites/default)
	$(call php, cp settings/settings.local.php web/sites/default/settings.local.php)
	$(call php-0, sed -i "/settings.local.php';/s/# //g" web/sites/default/settings.php)

cex:
	$(call php, drush cex -y)
ifneq ($(PROJECT_INSTALL), config)
	rm -rf config/sync/*
	cp -R web/$(shell docker-compose exec -T --user $(CUID):$(CGID) php drush ev 'echo substr(\Drupal::service("config.storage.sync")->getFilePath("drush"), 0, -10);')/* config/sync
endif

cim:
	$(call php, drush cr)
	$(call php, drush cim -y)

update-alias:
	$(call php, drush pag canonical_entities:node update)
	$(call php, drush cr)

info:
	$(info Containers for "$(COMPOSE_PROJECT_NAME)" info:)
	$(eval CONTAINERS := $(shell docker ps -f name=$(COMPOSE_PROJECT_NAME) --format "{{ .ID }}"))
	$(foreach CONTAINER, $(CONTAINERS),$(info $(shell docker inspect --format='{{.NetworkSettings.Networks.$(COMPOSE_PROJECT_NAME)_front.IPAddress}} : {{.Name}}' $(CONTAINER)) ))

chown:
# Use this goal to set permissions in docker container
	$(call php-0, /bin/sh -c "chown $(CUID):$(CGID) /var/www/html/web -R")
# Need this to fix files folder
	$(call php-0, /bin/sh -c "chown www-data: /var/www/html/web/sites/default/files -R")

exec:
	docker-compose exec --user $(CUID):$(CGID) php ash

exec0:
	docker-compose exec php ash

up: net
	@echo "Updating containers..."
	docker-compose pull --parallel
	@echo "Build and run containers..."
	docker-compose up -d --remove-orphans

down:
	@echo "Removing network & containers for $(COMPOSE_PROJECT_NAME)"
	@docker-compose down -v --remove-orphans

clean: DIRS := core libraries modules/contrib profiles/contrib sites themes/contrib
clean: info down
	@for i in $(DIRS); do if [ -d "web/$$i" ]; then echo "Removing web/$$i..."; docker run --rm -v $(shell pwd):/mnt $(IMAGE_PHP) sh -c "rm -rf /mnt/web/$$i"; fi; done

net:
ifeq ($(strip $(shell docker network ls | grep $(COMPOSE_NET_NAME))),)
ifneq ($(COMPOSE_SUBNET_RANGE),)
	docker network create --subnet $(COMPOSE_SUBNET_RANGE) $(COMPOSE_NET_NAME)
else
	docker network create $(COMPOSE_NET_NAME)
endif
endif
	@make -s _iprange

_iprange:
	$(shell grep -q -F 'IPRANGE=' .env || printf "\nIPRANGE=$(shell docker network inspect $(COMPOSE_PROJECT_NAME)_front --format '{{(index .IPAM.Config 0).Subnet}}')" >> .env)

front:
	@echo "Building front tasks..."
	docker pull $(IMAGE_FRONT)
	$(call front, bower install)
	$(call front)
	$(call php-0, rm -rf web/themes/$(THEME_NAME)/node_modules)

lint:
	@echo "Running linters..."
	$(call front, gulp lint)
	$(call php-0, rm -rf web/themes/$(THEME_NAME)/node_modules)

dev:
	@echo "Dev tasks..."
	$(call php, chmod -R 777 sites/default/files)
	$(call php, cp sites/default/default.services.yml sites/default/services.yml)
	$(call php, cp sites/example.settings.local.php sites/default/settings.local.php)
	$(call php, drush en devel devel_generate webform_devel kint -y)
	$(call php, drush pm-uninstall dynamic_page_cache page_cache -y)

phpcs:
	docker run --rm \
		-v $(shell pwd)/web/profiles/$(PROFILE_NAME):/work/profile \
		-v $(shell pwd)/web/modules/custom:/work/modules \
		-v $(shell pwd)/web/themes/$(THEME_NAME):/work/themes \
		skilldlabs/docker-phpcs-drupal phpcs -s --colors \
		--standard=Drupal,DrupalPractice \
		--extensions=php,module,inc,install,profile,theme,yml \
		--ignore=*.css,*.md,*.js .
	docker run --rm \
		-v $(shell pwd)/web/profiles/$(PROFILE_NAME):/work/profile \
		-v $(shell pwd)/web/modules/custom:/work/modules \
		-v $(shell pwd)/web/themes/$(THEME_NAME):/work/themes \
		skilldlabs/docker-phpcs-drupal phpcs -s --colors \
		--standard=Drupal,DrupalPractice \
		--extensions=js \
		--ignore=*.css,*.md,libraries/*,styleguide/* .

phpcbf:
	docker run --rm \
		-v $(shell pwd)/web/profiles/$(PROFILE_NAME):/work/profile \
		-v $(shell pwd)/web/modules/custom:/work/modules \
		-v $(shell pwd)/web/themes/$(THEME_NAME):/work/themes \
		skilldlabs/docker-phpcs-drupal phpcbf -s --colors \
		--standard=Drupal,DrupalPractice \
		--extensions=php,module,inc,install,profile,theme,yml,txt,md \
		--ignore=*.css,*.md,*.js .
	docker run --rm \
		-v $(shell pwd)/web/profiles/$(PROFILE_NAME):/work/profile \
		-v $(shell pwd)/web/modules/custom:/work/modules \
		-v $(shell pwd)/web/themes/$(THEME_NAME):/work/themes \
		skilldlabs/docker-phpcs-drupal phpcbf -s --colors \
		--standard=Drupal,DrupalPractice \
		--extensions=js \
		--ignore=*.css,*.md,libraries/*,styleguide/* .
