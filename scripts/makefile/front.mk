FRONT_PORT?=65200

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

clear-front:
	@echo "Clean of node_modules and compiled dist... To skip this action please set CLEAR_FRONT_PACKAGES=no in .env file"
	$(call frontexec, rm -rf /app/node_modules /app/dist)

## Install frontend dependencies & build assets
front: | front-install front-build

front-install:
	@if [ -d $(CURDIR)/web/themes/custom/$(THEME_NAME) ]; then \
		echo "- Theme directory found. Installing yarn dependencies..."; \
		docker pull $(IMAGE_FRONT); \
		$(call frontexec, node -v); \
		$(call frontexec, yarn -v); \
		$(call frontexec, yarn install --ignore-optional --check-files --prod); \
	else \
		echo "- Theme directory defined in .env file was not found. Skipping front-install."; \
	fi

front-build:
	@if [ -d $(CURDIR)/web/themes/custom/$(THEME_NAME) ]; then \
		echo "- Theme directory found. Building front assets..."; \
		docker pull $(IMAGE_FRONT); \
		$(call frontexec, node -v); \
		$(call frontexec, yarn -v); \
		$(call frontexec, yarn build --stats=verbose); \
	else \
		echo "- Theme directory defined in .env file was not found. Skipping front-build."; \
	fi

lintval:
	@if [ -d $(CURDIR)/web/themes/custom/$(THEME_NAME) ]; then \
		echo "- Theme directory found. Running theme linters..."; \
		docker pull $(IMAGE_FRONT); \
		$(call frontexec, node -v); \
		$(call frontexec, yarn -v); \
		$(call frontexec, yarn run lint); \
	else \
		echo "- Theme directory defined in .env file was not found. Skipping theme linters."; \
	fi

lint:
	@if [ -d $(CURDIR)/web/themes/custom/$(THEME_NAME) ]; then \
		echo "- Theme directory found. Running theme linters with fix..."; \
		docker pull $(IMAGE_FRONT); \
		$(call frontexec, node -v); \
		$(call frontexec, yarn -v); \
		$(call frontexec, yarn install --ignore-optional --check-files --prod); \
		$(call frontexec, yarn lint-fix); \
	else \
		echo "- Theme directory defined in .env file was not found. Skipping theme linters with fix."; \
	fi

storybook:
	@if [ -d $(CURDIR)/web/themes/custom/$(THEME_NAME) ]; then \
		echo "- Theme directory found. Running dynamic storybook..."; \
		docker pull $(IMAGE_FRONT); \
		$(call frontexec, node -v); \
		$(call frontexec, yarn -v); \
		$(call frontexec, yarn install --ignore-optional --check-files); \
		$(call frontexec, yarn run build); \
		$(call frontexec-with-port, yarn storybook -p $(FRONT_PORT)); \
	else \
		echo "- Theme directory defined in .env file was not found. Skipping dynamic storybook."; \
	fi

build-storybook:
	@if [ -d $(CURDIR)/web/themes/custom/$(THEME_NAME) ]; then \
		echo "- Theme directory found. Exporting static storybook..."; \
		docker pull $(IMAGE_FRONT); \
		$(call frontexec, node -v); \
		$(call frontexec, yarn -v); \
		$(call frontexec, yarn install --ignore-optional --check-files); \
		$(call frontexec, yarn run build); \
		$(call frontexec, yarn run build-storybook); \
	else \
		echo "- Theme directory defined in .env file was not found. Skipping dynamic storybook."; \
	fi

create-component:
	@echo "Create component CLI dialog... It assumed that you already have 'make storybook' or 'make build-storybook' finished"
	docker pull $(IMAGE_FRONT)
	$(call frontexec-with-interactive, yarn cc)
