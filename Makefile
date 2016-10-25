# Read project name from .env file
$(shell cp -n \.env.default \.env)
$(shell cp -n \.\/src\/docker\/docker-compose\.override\.yml\.default \.\/src\/docker\/docker-compose\.override\.yml)
include .env

all: | include net build install info

include:
ifeq ($(strip $(COMPOSE_PROJECT_NAME)),projectname)
#todo: ask user to make a project name and mv folders.
$(error Project name can not be default, please edit ".env" and set COMPOSE_PROJECT_NAME variable.)
endif

build: clean
	mkdir -p build
	mkdir -p /dev/shm/${COMPOSE_PROJECT_NAME}_mysql
	cp src/drush_make/*.make.yml build/

install:
	@echo "Updating containers..."
	docker-compose pull
	@echo "Build and run containers..."
	docker-compose up -d
	make -s reinstall

reinstall:
	docker-compose exec php drush make profile.make.yml --prepare-install --overwrite -y; \
	docker-compose exec php composer config repositories.drupal composer https://packages.drupal.org/8; \
	docker-compose exec php composer require $(COMPOSER_REQUIRE); \
	docker-compose exec php drush si $(PROFILE_NAME) --db-url=mysql://d8:d8@mysql/d8 --account-pass=admin -y --site-name="$(SITE_NAME)"; \
	make -s chown; \
	make -s front; \
	make -s info

info:
ifeq ($(shell docker inspect --format="{{ .State.Running }}" $(COMPOSE_PROJECT_NAME)_web 2> /dev/null),true)
	@echo Project IP: $(shell docker inspect --format='{{.NetworkSettings.Networks.$(COMPOSE_PROJECT_NAME)_front.IPAddress}}' $(COMPOSE_PROJECT_NAME)_web)
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
	docker exec -i -t $(COMPOSE_PROJECT_NAME)_php sh

clean: info
	@echo "Removing networks for $(COMPOSE_PROJECT_NAME)"
ifeq ($(shell docker inspect --format="{{ .State.Running }}" $(COMPOSE_PROJECT_NAME)_php 2> /dev/null),true)
	docker-compose down; \
	sudo rm -rf build
endif

net:
ifeq ($(strip $(shell docker network ls | grep $(COMPOSE_PROJECT_NAME))),)
	docker network create $(COMPOSE_PROJECT_NAME)_front
endif
	@make -s iprange

front:
	@echo "Building front tasks..."
	docker run --rm -v $(shell pwd)/src/$(PROFILE_NAME)/themes/$(THEME_NAME):/work skilldlabs/frontend:zen; \
	docker-compose exec php rm -rf profiles/$(PROFILE_NAME)/themes/$(THEME_NAME)/node_modules; \
	make -s chown

iprange:
	$(shell grep -q -F 'IPRANGE=' .env || echo "\nIPRANGE=$(shell docker network inspect $(COMPOSE_PROJECT_NAME)_front --format '{{(index .IPAM.Config 0).Subnet}}')" >> .env)
