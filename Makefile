# Read project name from .env file
SHELL = /bin/bash

include .env

ifeq ($(strip $(COMPOSE_PROJECT_NAME)),projectname)
$(error Project name can not be default, please edit ".env" and set COMPOSE_PROJECT_NAME variable.)
endif

all: | net build install info

build: clean
	mkdir -p build
	cp src/drush_make/*.make.yml build/

install:
	@echo "Updating containers..."
	docker-compose pull
	@echo "Build and run containers..."
	docker-compose up -d
	docker-compose exec php drush make profile.make.yml --prepare-install --overwrite -y; \
	docker-compose exec php composer require league/csv:^8.0 commerceguys/intl:~0.7 commerceguys/addressing:~0.8 commerceguys/zone:~0.7; \
	docker-compose exec php drush si $(PROFILE_NAME) --db-url=mysql://d8:d8@mysql/d8 --account-pass=admin -y; --site-name=$(COMPOSE_PROJECT_NAME)\
	rm build/*.make.yml; \
	make -s chown; \
	make -s front; \
	make -s info

# 3d party libraries should be installed from json file list
# docker-compose -p mazars exec php composer requi re league/csv:^8.0

info:
ifeq ($(shell docker inspect --format="{{ .State.Running }}" $(COMPOSE_PROJECT_NAME)_web 2> /dev/null),true)
	@echo Project IP: $(shell docker inspect --format='{{.NetworkSettings.Networks.$(COMPOSE_PROJECT_NAME)_front.IPAddress}}' $(COMPOSE_PROJECT_NAME)_web)
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
	docker-compose exec php /bin/sh -c "chown $(shell id -u):$(shell id -g) /var/www/html -R"; \
	docker-compose exec php /bin/sh -c "chmod 0777 /var/www/html -R"; \
	docker-compose down; \
	rm -rf build
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
	$(shell grep "IPRANGE" .env && sed -i "s/^IPRANGE=.*/IPRANGE="$(shell docker network inspect $(COMPOSE_PROJECT_NAME)_front --format '{{(index .IPAM.Config 0).Subnet}}' | sed -e 's/\//\\\\\//')"/" .env || printf "\nIPRANGE=$(shell docker network inspect $(COMPOSE_PROJECT_NAME)_front --format '{{(index .IPAM.Config 0).Subnet}}')" >> .env)
