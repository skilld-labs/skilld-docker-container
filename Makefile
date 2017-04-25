# Read project name from .env file
$(shell cp -n \.env.default \.env)
$(shell cp -n \Makefile.local.default \Makefile.local)
$(shell cp -n \.\/src\/docker\/docker-compose\.override\.yml\.default \.\/src\/docker\/docker-compose\.override\.yml)
include .env

all: | net build install info

# Include some usefull goals.
-include Makefile.tools

# First we need to check if user configured project.

include:
ifeq ($(strip $(COMPOSE_PROJECT_NAME)),projectname)
#todo: ask user to make a project name and mv folders.
$(error Project name can not be default, please edit ".env" and set COMPOSE_PROJECT_NAME variable.)
endif


# Totally clear containers and data inside.
  RUNNING_CONTAINERS := $(shell docker ps -f name=$(COMPOSE_PROJECT_NAME) --format "{{ .ID }}")

clean: info
	@echo $(RUNNING_CONTAINERS)
ifeq ($(strip $(RUNNING_CONTAINERS)),)
	@echo "Nothing to remove for $(COMPOSE_PROJECT_NAME)"
else
	@echo "Removing networks for $(COMPOSE_PROJECT_NAME)"
	docker-compose down
endif
	if [ -d "build" ]; then docker run --rm -v $(shell pwd):/mnt skilldlabs/$(PHP_IMAGE) ash -c "rm -rf /mnt/build"; fi

# Prepare folder structure for project.
build: clean
	mkdir -p build/docroot
	cp src/composer/docroot/index.php build/docroot
	mkdir -p /dev/shm/${COMPOSE_PROJECT_NAME}_mysql

# Installing project.
install:
	@echo "Updating containers..."
	docker-compose pull
	@echo "Build and run containers..."
	docker-compose up -d
	docker-compose exec -T php apk add --no-cache git shadow
	docker-compose exec -T php apk add --no-cache git shadow
	docker-compose exec -T php apk add --no-cache inotify-tools
	make -s build_users
	docker-compose exec -T php chown -hR $(UID):$(GID) /var/www/html
	make -s reinstall

# Start Drupal installation.
reinstall:
	cp src/composer/composer.json build/;
ifeq ($(shell test -e src/composer/composer.lock && echo -n yes),yes)
	cp src/composer/composer.lock build/
endif
	make -s composermerge;
	$(call execute,php,composer install --prefer-dist --optimize-autoloader);
ifneq ($(shell test -e build/sites/default/settings.php && echo -n yes),yes)
	$(call execute,php,cp sites/default/default.settings.php sites/default/settings.php);
	$(call execute,php,sed -i "s/.*file_public_path.*/\$$settings['file_public_path'] =  'docroot\/files';/" sites/default/settings.php);
endif

ifeq ($(shell test -e site_settings/settings.$(ENV).php && echo -n yes),yes)
	@echo "We have settings for $(ENV) environment, including it as settings.local.php";
	$(call execute,php,sed -i "/settings.local.php';/s/# //g" sites/default/settings.php);
	cp site_settings/settings.$(ENV).php build/settings.local.php; \
	$(call execute,php,mv settings.local.php sites/default/settings.local.php);
endif
	make -s si;
	$(call execute,php,sh -c "cd docroot && ln -s ../robots.txt && ln -s ../.htaccess");

# Merge several composer.json files.
composermerge:
ifeq ($(shell test -e src/composer/composer.$(ENV).json && echo -n yes),yes)
	@echo "We have local json for $(ENV) environment, including it";
	cp src/composer/composer.$(ENV).json build/composer.local.json
	$(call execute,php,composer config extra.merge-plugin.include composer.local.json);
	$(call execute,php,composer config extra.merge-plugin.recurse true);
	$(call execute,php,composer config extra.merge-plugin.replace false);
	$(call execute,php,composer config extra.merge-plugin.merge-dev true);
	$(call execute,php,composer config extra.merge-plugin.merge-extra true);
	$(call execute,php,composer config extra.merge-plugin.merge-extra-deep true);
	$(call execute,php,composer config extra.merge-plugin.merge-scripts true);
else
	$(info "Nothing to merge")
endif


update:
	make -s composermerge; \
	$(call execute,php,composer update --prefer-dist --optimize-autoloader);
	$(call execute,php,drush updb -y);
	$(call execute,php,drush pmu $(MODULES) -y);
	$(call execute,php,drush en $(MODULES) -y);
	make -s front; \
	make -s csim; \
	make -s trans; \
	make -s postinstall; \
	make -s rsync; \
	make -s info


# Install site, in case we dont have config folder, install minimal profile and export config
si:
	@echo "Installing $(SITE_NAME)"
ifeq ($($(ls -A config/sync)),)
	$(call execute,php,drush si minimal --db-url=mysql://d8:d8@mysql/d8 --account-pass=admin -y --site-name="$(SITE_NAME)"); \
	$(call execute,php,drush en config_split -y); \
	docker exec $(COMPOSE_PROJECT_NAME)_php sed -i "s/.*config_directories.*/\$$config_directories['sync'] =  'config\/sync';/" sites/default/settings.php;
	make -s csex
else
	$(call execute,php,drush si config_installer --db-url=mysql://d8:d8@mysql/d8 --account-pass=admin -y config_installer_sync_configure_form.sync_directory=config/sync);
	$(call execute,php,drush entup);
endif
ifeq ($(shell test -d src/modules/$(MODULES) && echo -n yes),yes)
	$(call execute,php,drush pmu $(MODULES) -y);
	$(call execute,php,drush en $(MODULES) -y);
endif
	make -s front; \
	make -s csim; \
	make -s trans; \
	make -s postinstall; \
	make -s rsync; \
	make -s info

# Goal to build frontend part.
front:
	@echo "Building front tasks..."
	docker pull skilldlabs/frontend:zen; \
	docker run --rm -v $(shell pwd)/src/themes/$(THEME_NAME):/work skilldlabs/frontend:zen bower install --allow-root; \
	docker run --rm -v $(shell pwd)/src/themes/$(THEME_NAME):/work skilldlabs/frontend:zen $$@; \
	docker-compose exec -T php rm -rf themes/custom/$(THEME_NAME)/node_modules; \
	docker-compose exec -T php chown -hR $(UID):$(GID) /var/www/html


# Detect existing network and create it.
net:
ifeq ($(strip $(shell docker network ls | grep $(COMPOSE_PROJECT_NAME))),)
	docker network create $(COMPOSE_PROJECT_NAME)_front
endif
	@make -s iprange

# Get subnet ip range.
iprange:
	$(shell grep -q -F 'IPRANGE=' .env || echo "\nIPRANGE=$(shell docker network inspect $(COMPOSE_PROJECT_NAME)_front --format '{{(index .IPAM.Config 0).Subnet}}')" >> .env)


# All tool are moved to Makefile.tools
# All drupal related target moved to Makefile.drupal
%: force
	@$(MAKE) -s -f Makefile.drupal $@
force: ;