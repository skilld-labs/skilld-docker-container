# Read project name from .env file
$(shell cp -n \.env.default \.env)
$(shell cp -n \.\/src\/docker\/docker-compose\.override\.yml\.default \.\/src\/docker\/docker-compose\.override\.yml)
include .env

# Setup PHP Variables based on package version
PHP_IMAGE=php:$(shell printf '%s' "$(PHP_VERSION)" | sed -e 's/\.//')-fpm
export PHP_IMAGE

all: | include net build install info

include:
ifeq ($(strip $(COMPOSE_PROJECT_NAME)),projectname)
#todo: ask user to make a project name and mv folders.
$(error Project name can not be default, please edit ".env" and set COMPOSE_PROJECT_NAME variable.)
endif

build: clean
	mkdir -p build
	mkdir -p /dev/shm/${COMPOSE_PROJECT_NAME}_mysql

install:
	@echo "Updating containers..."
	docker-compose pull
	@echo "Build and run containers..."
	docker-compose up -d
	docker-compose exec php apk add --no-cache git
	docker-compose exec -T php composer global require --prefer-dist "hirak/prestissimo:^0.3"
	make reinstall

reinstall:
	cp src/drush_make/*.make.yml build/; \
	docker-compose exec php time drush make profile.make.yml --concurrency=4 --prepare-install --overwrite -y; \
	rm build/*.make.yml
	docker-compose exec -T php composer config repositories.drupal composer https://packages.drupal.org/8
	docker-compose exec -T php time composer require -o --update-no-dev --no-suggest $(COMPOSER_REQUIRE)
	make -s front
	make -s si

si:
ifeq ($(PROJECT_INSTALL), config)
	-docker-compose exec -T php time drush si config_installer --db-url=mysql://d8:d8@mysql/d8 --account-pass=admin -y config_installer_sync_configure_form.sync_directory=sync
else
	docker-compose exec -T php drush si $(PROFILE_NAME) --db-url=mysql://d8:d8@mysql/d8 --account-pass=admin -y --site-name="$(SITE_NAME)"
	docker-compose exec php ash -c "drush locale-check && drush locale-update"
endif
	make -s chown
	make -s info

info:
ifeq ($(shell docker inspect --format="{{ .State.Running }}" $(COMPOSE_PROJECT_NAME)_web 2> /dev/null),true)
	@echo Project IP: $(shell docker inspect --format='{{.NetworkSettings.Networks.$(COMPOSE_PROJECT_NAME)_front.IPAddress}}' $(COMPOSE_PROJECT_NAME)_web)
endif
ifeq ($(shell docker inspect --format="{{ .State.Running }}" $(COMPOSE_PROJECT_NAME)_mail 2> /dev/null),true)
	@echo Mailhog IP: $(shell docker inspect --format='{{.NetworkSettings.Networks.$(COMPOSE_PROJECT_NAME)_front.IPAddress}}' $(COMPOSE_PROJECT_NAME)_mail)
endif
ifeq ($(shell docker inspect --format="{{ .State.Running }}" $(COMPOSE_PROJECT_NAME)_adminer 2> /dev/null),true)
	@echo Adminer IP: $(shell docker inspect --format='{{.NetworkSettings.Networks.$(COMPOSE_PROJECT_NAME)_front.IPAddress}}' $(COMPOSE_PROJECT_NAME)_adminer)
endif

chown:
# Use this goal to set permissions in docker container
	docker-compose exec php /bin/sh -c "chown $(shell id -u):$(shell id -g) /var/www/html -R"
# Need this to fix files folder
	docker-compose exec php /bin/sh -c "chown www-data: /var/www/html/sites/default/files -R"

exec:
	docker-compose exec php ash

clean: info
	@echo "Removing networks for $(COMPOSE_PROJECT_NAME)"
ifeq ($(shell docker inspect --format="{{ .State.Running }}" $(COMPOSE_PROJECT_NAME)_php 2> /dev/null),true)
	docker-compose down
endif
	if [ -d "build" ]; then docker run --rm -v $(shell pwd):/mnt skilldlabs/$(PHP_IMAGE) ash -c "rm -rf /mnt/build"; fi

net:
ifeq ($(strip $(shell docker network ls | grep $(COMPOSE_PROJECT_NAME))),)
	docker network create $(COMPOSE_PROJECT_NAME)_front
endif
	@make -s iprange

front:
	@echo "Building front tasks..."
	docker run -t --rm -v $(shell pwd)/src/themes/$(THEME_NAME):/work skilldlabs/frontend:zen; \
	docker-compose exec php rm -rf themes/custom/$(THEME_NAME)/node_modules
	make -s chown

iprange:
	$(shell grep -q -F 'IPRANGE=' .env || printf "\nIPRANGE=$(shell docker network inspect $(COMPOSE_PROJECT_NAME)_front --format '{{(index .IPAM.Config 0).Subnet}}')" >> .env)

devel:
	@echo "Setting up permissions ..."
	docker-compose exec php find sites/default -type d -exec chmod 777 {} \;
	docker-compose exec php find sites/default -type f -exec chmod 666 {} \;

	@echo "Setting up settings.yml ..."
	docker-compose exec php cp sites/default/default.services.yml sites/default/services.yml

	@echo "Setting up settings.local.yml ..."
	docker-compose exec php cp sites/example.settings.local.php sites/default/settings.local.php
	@echo "Setting up kint ..."
	-docker-compose exec php composer require drupal/devel
	-docker-compose exec php drush en devel devel_generate kint -y
	-docker-compose exec php drush pm-uninstall dynamic_page_cache internal_page_cache -y

	@echo "Disabling js/css aggregation"
	docker-compose exec php drush -y config-set system.performance css.preprocess 0
	docker-compose exec php drush -y config-set system.performance js.preprocess 0

	@echo "Setting up Twig in debug mode ..."
	docker-compose exec php sed -i "s:debug\: false:debug\: true:g" sites/default/services.yml
	docker-compose exec php sed -i "s:auto_reload\: null:auto_reload\: false:g" sites/default/services.yml
	docker-compose exec php sed -i "s:cache\: true:cache\: false:g" sites/default/services.yml

	@echo "Finishing: clean up / cache rebuild ..."
	-docker-compose exec php drush cr
	@make -s chown

phpcs:
	docker run --rm -v $(shell pwd)/src/$(PROFILE_NAME):/work skilldlabs/docker-phpcs-drupal phpcs --standard=Drupal --extensions=php,module,inc,install,test,profile,theme,info .
	docker run --rm -v $(shell pwd)/src/$(PROFILE_NAME):/work skilldlabs/docker-phpcs-drupal phpcs --standard=DrupalPractice --extensions=php,module,inc,install,test,profile,theme,info .

phpcbf:
	docker run --rm -v $(shell pwd)/src/$(PROFILE_NAME):/work skilldlabs/docker-phpcs-drupal phpcbf --standard=Drupal --extensions=php,module,inc,install,test,profile,theme,info .
	docker run --rm -v $(shell pwd)/src/$(PROFILE_NAME):/work skilldlabs/docker-phpcs-drupal phpcbf --standard=DrupalPractice --extensions=php,module,inc,install,test,profile,theme,info .

cex:
	docker-compose exec php ash -c "drush cex -y"
ifneq ($(PROJECT_INSTALL), config)
	rm -rf config/sync/*
	cp -R build/$(shell docker-compose exec php drush ev 'echo substr(\Drupal::service("config.storage.sync")->getFilePath("drush"), 0, -10);')/* config/sync
endif
