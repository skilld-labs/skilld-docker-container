# Read project name from .env file
COMPOSE_PROJECT_NAME := $(shell less .env  | grep -E 'COMPOSE_PROJECT_NAME' | sed 's/COMPOSE_PROJECT_NAME=//')

ifeq ($(strip $(COMPOSE_PROJECT_NAME)),projectname)
COMPOSE_PROJECT_NAME := $(shell read -p "Project name: " REPLY ; echo $$REPLY)
endif

ifeq ($(strip $(COMPOSE_PROJECT_NAME)),)
$(error Project name can not be blank.)
endif

build: clean
	$(shell mkdir -p build)
	docker-compose up -d
	cp src/drush_make/*.make.yml build/

#	docker-compose -p $(PROJECT_NAME) php drush make profile.make.yml --prepare-install --overwrite -y
#	rm build/*.make.yml

# docker-compose -p mazars exec php composer require league/csv:^8.0
#  $(shell docker inspect --format '{{ .NetworkSettings.Networks.mazars_front.IPAddress }}' mazars_web)

clean:
	docker-compose down

remove:
	@echo "Removing networks for $(COMPOSE_PROJECT_NAME)"
#	docker-compose stop
#	$(shell yes | docker-compose rm)
#	docker network rm $(shell less .env  | grep -E 'COMPOSE_PROJECT_NAME' | sed 's/COMPOSE_PROJECT_NAME=//')_back
#	docker network rm $(shell less .env  | grep -E 'COMPOSE_PROJECT_NAME' | sed 's/COMPOSE_PROJECT_NAME=//')_front
	docker network rm $(COMPOSE_PROJECT_NAME)_back
	docker network rm $(COMPOSE_PROJECT_NAME)_front
