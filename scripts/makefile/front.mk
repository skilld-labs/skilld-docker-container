# Execute front container function
front = docker run --rm -u $(CUID):$(CGID) -v $(shell pwd)/web/themes/custom/$(THEME_NAME):/work $(IMAGE_FRONT) ${1}

## Build front tasks
front:
	@echo "Building front tasks..."
	docker pull $(IMAGE_FRONT)
	$(call front, bower install)
	$(call front)
	$(call php-0, rm -rf web/themes/custom/$(THEME_NAME)/node_modules)

lint:
	@echo "Running linters..."
	$(call front, gulp lint)
	$(call php-0, rm -rf web/themes/custom/$(THEME_NAME)/node_modules)
