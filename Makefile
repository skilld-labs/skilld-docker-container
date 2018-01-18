# Read project name from .env file
$(shell cp -n \.env.default \.env)
$(shell cp -n \.\/docker\/docker-compose\.override\.yml\.default \.\/docker\/docker-compose\.override\.yml)
include .env
CUID ?= $(shell id -u)
CGID ?= $(shell id -g)
define execute
	time docker-compose exec -T --user $(CUID):$(CGID) ${1} ${2}
endef

.PHONY: all clean csim exec include install phpcbf reinstall build chown csex devel front info phpcs si

all: | include _net build install info

include:
ifeq ($(strip $(COMPOSE_PROJECT_NAME)),projectname)
#todo: ask user to make a project name and mv folders.
$(error Project name can not be default, please edit ".env" and set COMPOSE_PROJECT_NAME variable.)
endif

_build_users:
	$(eval WEB_USER_UID?=$(shell docker-compose exec -T php id www-data -u))
	$(eval WEB_USER_GID?=$(shell docker-compose exec -T php id www-data -g))
ifeq ($(CUID),33)
	@echo 'No needs to modify users inside container.'
else
ifneq ($(shell docker-compose exec php grep -c $(CUID) /etc/passwd),0)
	@echo 'User with the same UId exists, need to change his stuff.'
	$(eval CONTAINERS_GROUP_NAME ?= $(shell $(call execute,php,id -gn)))
	$(eval CONTAINERS_USER_NAME ?= $(shell $(call execute,php,id -un)))
	$(shell docker-compose exec -T php usermod -u 1001 $(CONTAINERS_USER_NAME))
	$(shell docker-compose exec -T php groupmod -g 1001 $(CONTAINERS_GROUP_NAME))
	$(shell docker-compose exec -T php find / -user $(CUID) -exec chown -h 1001 {} \;)
	$(shell docker-compose exec -T php find / -group $(CGID) -exec chgrp -h 1001 {} \;)
endif
	$(shell docker-compose exec -T php usermod -u $(CUID) www-data)
	$(shell docker-compose exec -T php groupmod -g $(CGID) www-data)
	$(shell docker-compose exec -T php find / -user $(WEB_USER_UID) 1>/dev/null -exec chown -h $(CUID) {} \;)
	$(shell docker-compose exec -T php find / -group $(WEB_USER_GID) 1>/dev/null -exec chgrp -h $(CGID) {} \; )
	@echo 'Restarting php container.'
	$(shell docker-compose restart php)
endif

build: clean
	mkdir -p /dev/shm/${COMPOSE_PROJECT_NAME}_mysql

install:
	@echo "Updating containers..."
	docker-compose pull --parallel
	@echo "Build and run containers..."
	docker-compose up -d
	docker-compose exec -T php chown -hR $(CUID):$(CGID) /var/www
	make -s _build_users
	$(call execute,php,composer global require hirak/prestissimo:^0.3);
	make -s reinstall

reinstall:
	$(call execute,php,composer install --prefer-dist --optimize-autoloader);
	$(call execute,php,composer drupal-scaffold);
	chmod u+w -R web/sites/default
ifeq ($(shell test -e settings/services.$(ENVIRONMENT).yml && echo -n yes),yes)
	@echo "We have services for $(ENVIRONMENT) environment, including it as services.yml"
	cp settings/services.$(ENVIRONMENT).yml web/sites/default/services.yml
endif
ifeq ($(shell test -e settings/settings.$(ENVIRONMENT).php && echo -n yes),yes)
	@echo "We have settings for $(ENVIRONMENT) environment, including it as settings.local.php"
	sed -i "/settings.local.php';/s/# //g" web/sites/default/default.settings.php
	cp settings/settings.$(ENVIRONMENT).php web/sites/default/settings.local.php
endif
	make -s front; \
	make -s si;

si:
	@echo "Installing from: $(PROJECT_INSTALL)"
	$(call execute,php,chmod +w web/sites/default/settings.php)
ifeq ($(PROJECT_INSTALL), config)
	$(call execute,php,drush si config_installer --db-url=$(DB_URL) --account-pass=admin -y config_installer_sync_configure_form.sync_directory=./../config/sync)
else
	$(call php, drush si $(PROFILE_NAME) --db-url=$(DB_URL) --account-pass=admin -y --site-name="$(SITE_NAME)" --site-mail="$(SITE_MAIL)" install_configure_form.site_default_country=FR install_configure_form.date_default_timezone=Europe/Paris)
endif
#	make -s lang-upcheck
#	make -s lang-import
	make -s csim
	make -s chown
	make -s info

updb:
	@echo "Updating environments"
	$(call execute,php,drush cr)
	$(call execute,php,drush cim -y)
	$(call execute,php,drush updb -y)
#	make -s lang-upcheck
#	make -s lang-import
	$(call execute,php,drush cr)
	@echo "Updating finished"

info:
	$(info Containers for "$(COMPOSE_PROJECT_NAME)" info:)
	$(eval CONTAINERS := $(shell docker ps -f name=$(COMPOSE_PROJECT_NAME) --format "{{ .ID }}"))
	$(foreach CONTAINER, $(CONTAINERS),$(info $(shell docker inspect --format='{{.NetworkSettings.Networks.$(COMPOSE_PROJECT_NAME)_front.IPAddress}} : {{.Name}}' $(CONTAINER)) ))

chown:
# Use this goal to set permissions in docker container
	docker-compose exec -T php /bin/sh -c "chown $(shell id -u):$(shell id -g) /var/www/html -R"
# Need this to fix files folder
	if [ -d "build/sites/default/files" ]; then docker-compose exec -T php /bin/sh -c "chown www-data: /var/www/html/sites/default/files -R"; fi

exec:
	docker-compose exec --user $(CUID):$(CGID) php /bin/bash

clean: info
	@echo "Removing networks for $(COMPOSE_PROJECT_NAME)"
ifeq ($(shell docker inspect --format="{{ .State.Running }}" $(COMPOSE_PROJECT_NAME)_php 2> /dev/null),true)
	docker-compose down
endif

_net:
ifeq ($(strip $(shell docker network ls | grep $(COMPOSE_PROJECT_NAME))),)
ifneq ($(SUBNET),)
	docker network create --subnet $(SUBNET) $(COMPOSE_PROJECT_NAME)_front
else
	docker network create $(COMPOSE_PROJECT_NAME)_front
endif	
endif
	@make -s _iprange

front:
	@echo "Building front tasks..."
	docker run -t --rm -u$(CUID):$(CGID) -v $(shell pwd)/web/themes/custom/$(THEME_NAME):/work skilldlabs/frontend:zen; \
	rm -rf web/themes/custom/$(THEME_NAME)/node_modules; \
	$(call execute,php,drush cr)

cr:
	$(call execute,php,drush cr)

_iprange:
	$(shell grep -q -F 'IPRANGE=' .env || printf "\nIPRANGE=$(shell docker network inspect $(COMPOSE_PROJECT_NAME)_front --format '{{(index .IPAM.Config 0).Subnet}}')" >> .env)

devel:
	@echo "Setting up permissions ..."
	$(call execute,php,find web/sites/default -type d -exec chmod 777 {} \;)
	$(call execute,php,find web/sites/default -type f -exec chmod 666 {} \;)

	@echo "Setting up settings.yml ..."
	$(call execute,php,cp web/sites/default/default.services.yml web/sites/default/services.yml)

	@echo "Setting up settings.local.yml ..."
	$(call execute,php,cp web/sites/example.settings.local.php web/sites/default/settings.local.php)
	@echo "Setting up kint ..."
	$(call execute,php,drush pm-uninstall dynamic_page_cache internal_page_cache -y)

	@echo "Setting up Twig in debug mode ..."
	$(call execute,php,sed -i "s:debug\: false:debug\: true:g" web/sites/default/services.yml)
	$(call execute,php,sed -i "s:auto_reload\: null:auto_reload\: false:g" web/sites/default/services.yml)
	$(call execute,php,sed -i "s:cache\: true:cache\: false:g" web/sites/default/services.yml)

	@echo "Finishing: clean up / cache rebuild ..."
	$(call execute,php,drush cr)
	@make -s chown

phpcs:
	docker run --rm \
		-v $(shell pwd)/web/profiles/$(PROFILE_NAME):/work/profile \
		-v $(shell pwd)/web/modules/custom:/work/modules \
		-v $(shell pwd)/web/themes/custom:/work/themes \
		skilldlabs/docker-phpcs-drupal phpcs -s --colors \
		--standard=Drupal,DrupalPractice \
		--extensions=php,module,inc,install,profile,theme,yml \
		--ignore=*.css,*.js,*.md,asset-builds/*,libraries/*,styleguide/* .
	docker run --rm \
		-v $(shell pwd)/web/profiles/$(PROFILE_NAME):/work/profile \
		-v $(shell pwd)/web/modules/custom:/work/modules \
		-v $(shell pwd)/web/themes/custom:/work/themes \
		skilldlabs/docker-phpcs-drupal phpcs -s --colors \
		--standard=Drupal,DrupalPractice \
		--extensions=js \
		--ignore=*.css,*.md,asset-builds/*,libraries/*,styleguide/* .

phpcbf:
	docker run --rm \
		-v $(shell pwd)/web/profiles/$(PROFILE_NAME):/work/profile \
		-v $(shell pwd)/web/modules/custom:/work/modules \
		-v $(shell pwd)/web/themes/custom:/work/themes \
		skilldlabs/docker-phpcs-drupal phpcbf -s --colors \
		--standard=Drupal,DrupalPractice \
		--extensions=php,module,inc,install,profile,theme,yml \
		--ignore=*.css,*.js,*.md,asset-builds/*,libraries/*,styleguide/* .
	docker run --rm \
		-v $(shell pwd)/web/profiles/$(PROFILE_NAME):/work/profile \
		-v $(shell pwd)/web/modules/custom:/work/modules \
		-v $(shell pwd)/web/themes/custom:/work/themes \
		skilldlabs/docker-phpcs-drupal phpcbf -s --colors \
		--standard=Drupal,DrupalPractice \
		--extensions=js \
		--ignore=*.css,*.md,asset-builds/*,libraries/*,styleguide/*,gulpfile.js .

csex:
	$(call execute,php,drush cex -y)

csim:
	$(call execute,php,drush cim -y)

lang-upcheck:
	$(call execute,php,drush locale-check)
	$(call execute,php,drush locale-update)

lang-import:
	$(call execute,php,drush langimp fr profiles/$(PROFILE_NAME)/translations/fr.po --replace)
	$(call execute,php,drush langimp en profiles/$(PROFILE_NAME)/translations/en.po --replace)

