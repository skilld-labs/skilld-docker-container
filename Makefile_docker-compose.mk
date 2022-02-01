


# Define network name
COMPOSE_NET_NAME := $(COMPOSE_PROJECT_NAME)_front
# Define docker-compose files
COMPOSE_FILE=./docker/docker-compose.yml:./docker/docker-compose.override.yml



xxx:
	@echo "im in docker-compose.mk"



LOCAL_IP = $(shell docker inspect --format='{{(index .NetworkSettings.Networks "$(COMPOSE_NET_NAME)").IPAddress}}:{{index .Config.Labels "traefik.port"}}' $(COMPOSE_PROJECT_NAME)_web)



# ifneq ($(shell diff docker/docker-compose.override.yml docker/docker-compose.override.yml.default -q),)
# 	@echo -e "\x1b[33mWARNING\x1b[0m - docker/docker-compose.override.yml and docker/docker-compose.override.yml.default files differ. Use 'make diff' to see details."
# endif

down-test-browser:
	@if [ ! -z "$(shell docker ps -f 'name=$(COMPOSE_PROJECT_NAME)_chrome' --format '{{.Names}}')" ]; then \
		echo 'Stoping browser driver.' && make -s browser_driver_stop; fi
