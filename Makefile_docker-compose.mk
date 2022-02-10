$(shell false | cp -i \.\/docker\/docker-compose\.override\.yml\.default \.\/docker\/docker-compose\.override\.yml 2>/dev/null)



# Define network name
COMPOSE_NET_NAME := $(COMPOSE_PROJECT_NAME)_front
# Define docker-compose files
COMPOSE_FILE=./docker/docker-compose.yml:./docker/docker-compose.override.yml
# List docker-compose services
SDC_SERVICES=$(shell docker-compose config --services)

LOCAL_IP = $(shell docker inspect --format='{{(index .NetworkSettings.Networks "$(COMPOSE_NET_NAME)").IPAddress}}:{{index .Config.Labels "traefik.port"}}' $(COMPOSE_PROJECT_NAME)_web)

PROJECT_IS_UP = 

# Execute php container as regular user
php = docker-compose exec -T --user $(CUID):$(CGID) php ${1}
# Execute php container as root user
php-0 = docker-compose exec -T --user 0:0 php ${1}



## Run shell in PHP container as regular user
exec:
	docker-compose exec --user $(CUID):$(CGID) php ash

## Run shell in PHP container as root
exec0:
	docker-compose exec --user 0:0 php ash



## Output diff between local and versioned files
diff:
	diff -u0 --color .env .env.default || true; echo ""
	diff -u0 --color docker/docker-compose.override.yml docker/docker-compose.override.yml.default || true; echo ""


down-test-browser:
	@if [ ! -z "$(shell docker ps -f 'name=$(COMPOSE_PROJECT_NAME)_chrome' --format '{{.Names}}')" ]; then \
		echo 'Stoping browser driver.' && make -s browser_driver_stop; fi


provision:
	docker-compose up -d --remove-orphans


## Display project's information
info:
	$(info )
	$(info Containers for "$(COMPOSE_PROJECT_NAME)" info:)
	$(eval CONTAINERS = $(shell docker ps -f name=$(COMPOSE_PROJECT_NAME) --format "{{ .ID }}" -f 'label=traefik.enable=true'))
	$(foreach CONTAINER, $(CONTAINERS),$(info http://$(shell printf '%-19s \n'  $(shell docker inspect --format='{{(index .NetworkSettings.Networks "$(COMPOSE_NET_NAME)").IPAddress}}:{{index .Config.Labels "traefik.port"}} {{range $$p, $$conf := .NetworkSettings.Ports}}{{$$p}}{{end}} {{.Name}}' $(CONTAINER) | rev | sed "s/pct\//,pct:/g" | sed "s/,//" | rev | awk '{ print $0}')) ))
	$(info )
ifdef REVIEW_DOMAIN
	$(eval BASE_URL := $(MAIN_DOMAIN_NAME))
else
	$(eval BASE_URL := $(shell docker inspect --format='{{(index .NetworkSettings.Networks "$(COMPOSE_NET_NAME)").IPAddress}}:{{index .Config.Labels "traefik.port"}}' $(COMPOSE_PROJECT_NAME)_web))
endif
	$(info Login as System Admin: http://$(shell printf '%-19s \n'  $(shell echo "$(BASE_URL)"$(shell $(call php, drush user:login --name="$(ADMIN_NAME)" /admin/content/ | awk -F "default" '{print $$2}')))))
	$(info Login as Contributor: http://$(shell printf '%-19s \n'  $(shell echo "$(BASE_URL)"$(shell $(call php, drush user:login --name="$(TESTER_NAME)" /admin/content/ | awk -F "default" '{print $$2}')))))
	$(info )
ifneq ($(shell diff .env .env.default -q),)
	@echo -e "\x1b[33mWARNING\x1b[0m - .env and .env.default files differ. Use 'make diff' to see details."
endif
ifneq ($(shell diff docker/docker-compose.override.yml docker/docker-compose.override.yml.default -q),)
	@echo -e "\x1b[33mWARNING\x1b[0m - docker/docker-compose.override.yml and docker/docker-compose.override.yml.default files differ. Use 'make diff' to see details."
endif


down:
	@docker-compose down -v --remove-orphans --rmi local
	@if [ ! -z "$(shell docker ps -f 'name=$(COMPOSE_PROJECT_NAME)_chrome' --format '{{.Names}}')" ]; then \
		echo 'Stoping browser driver.' && make -s browser_driver_stop; fi


## Totally remove project build folder, docker containers and network
clean:
	make -s down
	$(eval SCAFFOLD = $(shell docker run --rm -v $(CURDIR):/mnt -w /mnt --user $(CUID):$(CGID) $(IMAGE_PHP) composer run-script list-scaffold-files | grep -P '^(?!>)'))
	@docker run --rm --user 0:0 -v $(CURDIR):/mnt -w /mnt -e RMLIST="$(addprefix web/,$(SCAFFOLD)) $(DIRS)" $(IMAGE_PHP) sh -c 'for i in $$RMLIST; do rm -fr $$i && echo "Removed $$i"; done'
ifdef DB_MOUNT_DIR
	@echo "Clean-up database data from $(DB_MOUNT_DIR) ..."
	docker run --rm --user 0:0 -v $(shell dirname $(DB_MOUNT_DIR)):/mnt $(IMAGE_PHP) sh -c "rm -fr /mnt/`basename $(DB_MOUNT_DIR)`"
endif
ifeq ($(CLEAR_FRONT_PACKAGES), yes)
	make clear-front
endif


# Execute front container function.
frontexec = docker run \
	--rm \
	--init \
	-u $(CUID):$(CGID) \
	-v $(CURDIR)/web/themes/custom/$(THEME_NAME):/app \
	--workdir /app \
	$(IMAGE_FRONT) ${1}


# Execute front container function on localhost:FRONT_PORT. Needed for dynamic storybook.
frontexec-with-port = docker run \
	--rm \
	--init \
	-p $(FRONT_PORT):$(FRONT_PORT) \
	-u $(CUID):$(CGID) \
	-v $(CURDIR)/web/themes/custom/$(THEME_NAME):/app \
	--workdir /app \
	$(IMAGE_FRONT) ${1}

# Execute front container with TTY. Needed for storybook components creation.
frontexec-with-interactive = docker run \
	--rm \
	--init \
	-u $(CUID):$(CGID) \
	-v $(CURDIR)/web/themes/custom/$(THEME_NAME):/app \
	--workdir /app \
	-it \
	$(IMAGE_FRONT) ${1}



testfront:
	$(call frontexec,ls -lah)

xxx:
	@echo "im in docker-compose.mk"

