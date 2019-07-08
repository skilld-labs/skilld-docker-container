# Evaluate recursively.
CUID ?= $(LOCAL_UID)
CGID ?= $(LOCAL_GID)
CLEAR_FRONT_PACKAGES?=yes
FRONT_PORT?=65200

# Execute front container function.
front = docker run \
	--rm \
	--init \
	-p $(FRONT_PORT):$(FRONT_PORT) \
	-u $(CUID):$(CGID) \
	-v $(shell pwd)/web/themes/custom/$(THEME_NAME):/app \
	--workdir /app \
	$(IMAGE_FRONT) ${1}

clear-front:
ifeq ($(CLEAR_FRONT_PACKAGES), yes)
	@echo "Clean of node_modules... To skip this action please set CLEAR_FRONT_PACKAGES=no in .env file"
	$(call front, rm -rf /app/node_modules)
endif

front:
	@echo "Running front tasks..."
	docker pull $(IMAGE_FRONT)
	$(call front, yarn install --prod --ignore-optional --check-files)
	$(call front, yarn build --verbose)
	make clear-front

lint:
	@echo "Running theme linters with fix..."
	docker pull $(IMAGE_FRONT)
	$(call front, yarn install --prod --ignore-optional --check-files)
	$(call front, yarn lint-fix)

storybook:
	@echo "Running storybook..."
	docker pull $(IMAGE_FRONT)
	$(call front, yarn install --ignore-optional --check-files)
	$(call front, yarn storybook -p $(FRONT_PORT))
