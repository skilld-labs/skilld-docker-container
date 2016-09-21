# Read project name from .env file
SHELL = /bin/bash

include .env

ifeq ($(strip $(COMPOSE_PROJECT_NAME)),projectname)
$(error Project name can not be default, please edit ".env" and set COMPOSE_PROJECT_NAME variable.)
endif

all: | build install info
build: clean
	mkdir -p build
# 3d party libraries should be
# docker-compose -p mazars exec php composer require league/csv:^8.0
#	@echo Project IP: $(shell docker inspect --format='{{.NetworkSettings.Networks.$(COMPOSE_PROJECT_NAME)_front.IPAddress}}' $(COMPOSE_PROJECT_NAME)_web)

install:
	cp src/drush_make/*.make.yml build/
	docker-compose up -d
	docker-compose exec php drush make profile.make.yml --prepare-install --overwrite -y
	#docker exec chown $(shell id -u):$(shell id -g) /var/www/html -R
	rm build/*.make.yml

clean: remove
	rm -rf build

info:
	@echo Project IP: $(shell docker inspect --format='{{.NetworkSettings.Networks.$(COMPOSE_PROJECT_NAME)_front.IPAddress}}' $(COMPOSE_PROJECT_NAME)_web)

chown:
#  docker exec $(COMPOSE_PROJECT_NAME)_php chown $(shell id -u):$(shell id -g) /var/www/html -R
	docker-compose exec php /bin/sh -c "chown $(shell id -u):$(shell id -g) /var/www/html -R"

exec:
	docker exec -i -t $(COMPOSE_PROJECT_NAME)_php sh

remove:
	@echo "Removing networks for $(COMPOSE_PROJECT_NAME)"
	docker-compose down