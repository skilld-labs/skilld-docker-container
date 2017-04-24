# Read project name from .env file
$(shell cp -n \.env.default \.env)
$(shell cp -n \Makefile.local.default \Makefile.local)
$(shell cp -n \.\/src\/docker\/docker-compose\.override\.yml\.default \.\/src\/docker\/docker-compose\.override\.yml)
include .env

# Include some usefull goals.
include Makefile.tools

all: | include net build install info

# First we need to check if user configured project.
include:
ifeq ($(strip $(COMPOSE_PROJECT_NAME)),projectname)
#todo: ask user to make a project name and mv folders.
$(error Project name can not be default, please edit ".env" and set COMPOSE_PROJECT_NAME variable.)
endif


# Totally clear containers and data inside.
clean: info
	@echo "Removing networks for $(COMPOSE_PROJECT_NAME)"
ifeq ($(shell docker inspect --format="{{ .State.Running }}" $(COMPOSE_PROJECT_NAME)_php 2> /dev/null),true)
	docker-compose down
endif
	if [ -d "build" ]; then docker run --rm -v $(shell pwd):/mnt skilldlabs/$(PHP_IMAGE) ash -c "rm -rf /mnt/build"; fi

# Prepare folder structure for project.
build: clean
	mkdir -p build/docroot
	cp src/composer/docroot/index.php build/docroot
	mkdir -p /dev/shm/${COMPOSE_PROJECT_NAME}_mysql

install:
	@echo "Updating containers..."
	docker-compose pull
	@echo "Build and run containers..."
	docker-compose up -d
	docker-compose exec -T php apk add --no-cache git shadow
	make -s build_users
	docker-compose exec -T php chown -hR $(UID):$(GID) /var/www/html
	make -s reinstall

reinstall:
	cp src/composer/composer.json build/;
ifeq ($(shell test -e src/composer/composer.lock && echo -n yes),yes)
	cp src/composer/composer.lock build/
endif
	make -s composermerge;
	$(call execute,php,composer install --prefer-dist --optimize-autoloader);
	$(call execute,php,cp sites/default/default.settings.php sites/default/settings.php);

ifeq ($(shell test -e site_settings/settings.$(ENV).php && echo -n yes),yes)
	@echo "We have settings for $(ENV) environment, including it as settings.local.php";
	$(call execute,php,sed -i "/settings.local.php';/s/# //g" sites/default/settings.php);
	cp site_settings/settings.$(ENV).php build/settings.local.php; \
	$(call execute,php,mv settings.local.php sites/default/settings.local.php);
endif
	$(call execute,php,sed -i "s/.*file_public_path.*/\$$settings['file_public_path'] =  'docroot\/files';/" sites/default/settings.php);
	make -s si;
	$(call execute,php,sh -c "cd docroot && ln -s ../robots.txt && ln -s ../.htaccess");


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
endif


update:
	make -s composermerge; \
	$(call execute,php,composer update --prefer-dist --optimize-autoloader);
	$(call execute,php,drush updb -y);
	$(call execute,php,drush pmu $(MODULES) -y);
	$(call execute,php,drush en $(MODULES) -y);
	make -s trans; \
	make -s front; \
	make -s postinstall; \
	make -s csim; \
	make -s rsync; \
	make -s info

si:
	@echo "Installing from: $(PROJECT_INSTALL)"
ifeq ($(PROJECT_INSTALL), config)
	$(call execute,php,drush si config_installer --db-url=mysql://d8:d8@mysql/d8 --account-pass=admin -y config_installer_sync_configure_form.sync_directory=config/sync);
	$(call execute,php,drush eval '\Drupal::service("entity.definition_update_manager")->applyUpdates();');
	$(call execute,php,drush pmu $(MODULES) -y);
else
	docker-compose exec -T php drush si $(PROFILE_NAME) --db-url=mysql://d8:d8@mysql/d8 --account-pass=admin -y --site-name="$(SITE_NAME)"
endif
	$(call execute,php,drush en $(MODULES) -y);
	make -s trans; \
	make -s postinstall; \
	make -s csim; \
	make -s rsync; \
	make -s info

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