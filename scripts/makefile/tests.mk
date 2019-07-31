# Function for code sniffer images.
phpcsexec = docker run --rm \
	-v $(shell pwd)/web/profiles/$(PROFILE_NAME):/work/profile \
	-v $(shell pwd)/web/modules/custom:/work/modules \
	-v $(shell pwd)/web/themes/custom:/work/themes \
	skilldlabs/docker-phpcs-drupal ${1} -s --colors \
	--standard=Drupal,DrupalPractice \
	--extensions=php,module,inc,install,profile,theme,yml,txt,md,js \
	--ignore=*.css,libraries/*,dist/*,styleguide/*,README.md,README.txt,node_modules/*,$(THEME_NAME)/**.js \
	.

## Validate codebase with phpcs sniffers to make sure it conforms https://www.drupal.org/docs/develop/standards
phpcs:
	@echo "Phpcs validation..."
	@$(call phpcsexec, phpcs)

## Fix codebase according to Drupal standards https://www.drupal.org/docs/develop/standards
phpcbf:
	@$(call phpcsexec, phpcbf)


## Add symbolic link from custom script(s) to .git/hooks/
hooksymlink:
# Check if .git directory exists
ifneq ($(wildcard .git/.*),)
# Check if script file exists
ifneq ("$(wildcard scripts/git_hooks/sniffers.sh)","")
	@echo "Removing previous git hooks and installing fresh ones"
	$(shell find .git/hooks -type l -exec unlink {} \;)
	$(shell ln -sf ../../scripts/git_hooks/sniffers.sh .git/hooks/pre-push)
else
	@echo "scripts/git_hooks/sniffers.sh file does not exist"
endif
else
	@echo "No git directory found, git hooks won't be installed"
endif


## Validate langcode of base config files
clang:
ifneq ("$(wildcard scripts/makefile/baseconfig-langcode.sh)","")
	@echo "Base config langcode validation..."
	@/bin/sh ./scripts/makefile/baseconfig-langcode.sh
else
	@echo "scripts/makefile/baseconfig-langcode.sh file does not exist"
endif


## Validate configuration schema
cinsp:
ifneq ("$(wildcard scripts/makefile/config-inspector-validation.sh)","")
	@echo "Config schema validation..."
	$(call php, composer install -o)
	@$(call php, /bin/sh ./scripts/makefile/config-inspector-validation.sh)
else
	@echo "scripts/makefile/config-inspector-validation.sh file does not exist"
endif


## Validate composer.json file
compval:
	@echo "Composer.json validation..."
	@docker run --rm -v `pwd`:`pwd` -w `pwd` $(IMAGE_PHP) composer validate --strict


## Validate watchdog logs
watchdogval:
ifneq ("$(wildcard scripts/makefile/watchdog-validation.sh)","")
	@echo "Watchdog validation..."
	@$(call php, /bin/sh ./scripts/makefile/watchdog-validation.sh)
else
	@echo "scripts/makefile/watchdog-validation.sh file does not exist"
endif


## Validate drupal-check
drupalcheckval:
	@echo "Drupal-check validation..."
	$(call php, composer install -o)
	$(call php, vendor/bin/drupal-check -V)
	$(call php, vendor/bin/drupal-check -ad -vv -n --no-progress web/modules/custom/)

## Validate Behat scenarios
behat:
	@echo "Getting base url"
ifdef REVIEW_DOMAIN
	$(eval BASE_URL := $(MAIN_DOMAIN_NAME))
else
	$(eval BASE_URL := $(shell docker inspect --format="{{.NetworkSettings.Networks.$(COMPOSE_NET_NAME).IPAddress}}" $(COMPOSE_PROJECT_NAME)_web))
endif
ifeq ($(shell docker ps -f 'name=$(COMPOSE_PROJECT_NAME)_chrome' --format '{{.Names}}'), )
	@echo 'Browser driver is stoped. Running it.'
	make -s browser_driver
endif
	@echo "Replacing URL_TO_TEST value in behat.yml with http://$(BASE_URL)"
	$(call php, cp behat.default.yml behat.yml)
	$(call php, sed -i "s/URL_TO_TEST/http:\/\/$(BASE_URL)/" behat.yml)
	@echo "Running Behat scenarios against http://$(BASE_URL)"
	$(call php, composer install -o)
	$(call php, vendor/bin/behat -V)
	$(call php, vendor/bin/behat --colors)

behatdl:
	$(call php, vendor/bin/behat -dl --colors)

behatdi:
	$(call php, vendor/bin/behat -di --colors)

## Run browser driver for behat tests
browser_driver:
	docker run -d --init --rm --name $(COMPOSE_PROJECT_NAME)_chrome \
	--network container:$(COMPOSE_PROJECT_NAME)_php $(IMAGE_DRIVER) \
	--remote-debugging-address=0.0.0.0 --remote-debugging-port=9222 --no-sandbox \
	--entrypoint "" chromium-browser --headless --disable-gpu \
	--window-size=1200,2080 \
	--disable-web-security

## Stop browser driver
browser_driver_stop:
	docker stop $(COMPOSE_PROJECT_NAME)_chrome

## Run sniffer validations (executed as git hook, by scripts/git_hooks/sniffers.sh)
sniffers: | clang compval phpcs

## Run all tests & validations (including sniffers)
tests: | sniffers behat cinsp drupalcheckval watchdogval