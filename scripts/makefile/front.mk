FRONT_PORT?=65200

# Execute front container function.
frontexec = docker run \
	--rm \
	--init \
	-p $(FRONT_PORT):$(FRONT_PORT) \
	-u $(CUID):$(CGID) \
	-v $(shell pwd)/web/themes/custom/$(THEME_NAME):/app \
	--workdir /app \
	$(IMAGE_FRONT) ${1}

clear-front:
	@echo "Clean of node_modules and compiled dist... To skip this action please set CLEAR_FRONT_PACKAGES=no in .env file"
	$(call frontexec, rm -rf /app/node_modules /app/dist)

front:
	@if [ -d $(shell pwd)/web/themes/custom/$(THEME_NAME) ]; then \
		echo "Running front tasks..."; \
		docker pull $(IMAGE_FRONT); \
		$(call frontexec, yarn install --prod --ignore-optional --check-files); \
		$(call frontexec, yarn build --verbose); \
	else \
		echo "Theme directory not found. Skipping front tasks."; \
	fi

lint:
	@echo "Running theme linters with fix..."
	docker pull $(IMAGE_FRONT)
	$(call frontexec, yarn install --prod --ignore-optional --check-files)
	$(call frontexec, yarn lint-fix)

storybook:
	@echo "Running storybook..."
	docker pull $(IMAGE_FRONT)
	$(call frontexec, yarn install --ignore-optional --check-files)
	$(call frontexec, yarn storybook -p $(FRONT_PORT))
