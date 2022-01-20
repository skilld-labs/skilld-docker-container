FRONT_PORT?=65200
RANDOM_STRING = $(shell cat /dev/urandom | tr -dc 'a-fA-F0-9' | tr '[:upper:]' '[:lower:]' | fold -w 10 | head -n 1)

# Execute front container function.
frontexec = docker run \
	--rm \
	--init \
	-u $(CUID):$(CGID) \
	-v $(CURDIR)/web/themes/custom/$(THEME_NAME):/app \
	--workdir /app \
	$(IMAGE_FRONT) ${1}



# Execute front container with TTY. Needed for storybook components creation.

clear-front:
	@echo "Clean of node_modules and compiled dist... To skip this action please set CLEAR_FRONT_PACKAGES=no in .env file"
	$(call frontexec,rm -rf /app/node_modules /app/dist)

## Install frontend dependencies & build assets
front: | front-install front-build

front-install:
	@if [ -d $(CURDIR)/web/themes/custom/$(THEME_NAME) ]; then \
		echo "- Theme directory found. Installing yarn dependencies..."; \
		$(call frontexec,node -v); \
		$(call frontexec,yarn -v); \
		$(call frontexec,yarn install --ignore-optional --check-files --prod); \
	else \
		echo "- Theme directory defined in .env file was not found. Skipping front-install."; \
	fi

front-build:
	@if [ -d $(CURDIR)/web/themes/custom/$(THEME_NAME) ]; then \
		echo "- Theme directory found. Building front assets..."; \
		$(call frontexec,node -v); \
		$(call frontexec,yarn -v); \
		$(call frontexec,yarn build --stats=verbose); \
	else \
		echo "- Theme directory defined in .env file was not found. Skipping front-build."; \
	fi

lintval:
	@if [ -d $(CURDIR)/web/themes/custom/$(THEME_NAME) ]; then \
		echo "- Theme directory found. Running theme linters..."; \
		$(call frontexec,node -v); \
		$(call frontexec,yarn -v); \
		$(call frontexec,yarn run lint); \
	else \
		echo "- Theme directory defined in .env file was not found. Skipping theme linters."; \
	fi

lint:
	@if [ -d $(CURDIR)/web/themes/custom/$(THEME_NAME) ]; then \
		echo "- Theme directory found. Running theme linters with fix..."; \
		$(call frontexec,node -v); \
		$(call frontexec,yarn -v); \
		$(call frontexec,yarn install --ignore-optional --check-files --prod); \
		$(call frontexec,yarn lint-fix); \
	else \
		echo "- Theme directory defined in .env file was not found. Skipping theme linters with fix."; \
	fi



# Execute front container function on localhost:FRONT_PORT. Needed for dynamic storybook.
frontexec-with-port = docker run \
	--rm \
	--init \
	-p $(FRONT_PORT):$(FRONT_PORT) \
	-u $(CUID):$(CGID) \
	-v $(CURDIR)/web/themes/custom/$(THEME_NAME):/app \
	--workdir /app \
	$(IMAGE_FRONT) ${1}

storybook:
	@if [ -d $(CURDIR)/web/themes/custom/$(THEME_NAME) ]; then \
		echo "- Theme directory found. Running dynamic storybook..."; \
		$(call frontexec,node -v); \
		$(call frontexec,yarn -v); \
		$(call frontexec,yarn install --ignore-optional --check-files); \
		$(call frontexec,yarn run build); \
		$(call frontexec-with-port,yarn storybook -p $(FRONT_PORT)); \
	else \
		echo "- Theme directory defined in .env file was not found. Skipping dynamic storybook."; \
	fi




build-storybook:
	@if [ -d $(CURDIR)/web/themes/custom/$(THEME_NAME) ]; then \
		echo "- Theme directory found. Exporting static storybook..."; \
		$(call frontexec,node -v); \
		$(call frontexec,yarn -v); \
		$(call frontexec,yarn install --ignore-optional --check-files); \
		$(call frontexec,yarn run build); \
		$(call frontexec,yarn run build-storybook); \
	else \
		echo "- Theme directory defined in .env file was not found. Skipping dynamic storybook."; \
	fi

# Execute front container with TTY. Needed for storybook components creation.
create-component:
	@echo "Create component CLI dialog... It assumed that you already have 'make storybook' or 'make build-storybook' finished"
	$(call frontexec-with-interactive,yarn cc)


frontexec-with-interactive = kubectl run "$(COMPOSE_PROJECT_NAME)-$(RANDOM_STRING)" --image=$(IMAGE_FRONT) --rm -i --overrides='{ "kind": "Pod", "apiVersion": "v1", "spec": { "volumes": [ { "name": "host-volume", "hostPath": { "path": "$(CURDIR)/web/themes/custom/$(THEME_NAME)" } } ], "containers": [ { "name": "$(RANDOM_STRING)", "image": "$(IMAGE_FRONT)", "command": $(shell $(call jsonarrayconverter,${1})), "stdin": true, "tty": true, "workingDir": "/app", "volumeMounts": [ { "name": "host-volume", "mountPath": "/app" } ], "terminationMessagePolicy": "FallbackToLogsOnError", "imagePullPolicy": "IfNotPresent" } ], "restartPolicy": "Never", "securityContext": { "runAsUser": $(CUID), "runAsGroup": $(CGID) } } }'

jsonarrayconverter = echo -n "${1}" | gojq -cRs 'split(" ")'

vv:
	$(call jsonarrayconverter,test string)
