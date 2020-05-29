# Function for code sniffer images.
phpcsexec = docker run --rm \
	-v $(shell pwd)/web/profiles/$(PROFILE_NAME):/work/profile \
	-v $(shell pwd)/web/modules/custom:/work/modules \
	-v $(shell pwd)/web/themes/custom:/work/themes \
	skilldlabs/docker-phpcs-drupal ${1} -s --colors \
	--standard=Drupal,DrupalPractice \
	--extensions=php,module,inc,install,profile,theme,yml,txt,md,js \
	--ignore=*.css,libraries/*,dist/*,README.md,README.txt,node_modules/*,work/themes/**.js,work/themes/**.md \
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
	# Add --strict back when page_manager includes https://www.drupal.org/project/page_manager/issues/2960739 in next release.
	@docker run --rm -v `pwd`:`pwd` -w `pwd` $(IMAGE_PHP) composer validate

## Validate hook_update_N()
hookupdateval:
ifneq ("$(wildcard scripts/makefile/hookupdateval.sh)","")
	@echo "hook_update_N() validation..."
	@/bin/sh ./scripts/makefile/hookupdateval.sh
else
	@echo "scripts/makefile/hookupdateval.sh.sh file does not exist"
endif

## Validate watchdog logs
watchdogval:
ifneq ("$(wildcard scripts/makefile/watchdog-validation.sh)","")
	@echo "Watchdog validation..."
	@$(call php, /bin/sh ./scripts/makefile/watchdog-validation.sh)
else
	@echo "scripts/makefile/watchdog-validation.sh file does not exist"
endif

## Validate status report
statusreportval:
ifneq ("$(wildcard scripts/makefile/status-report-validation.sh)","")
	@echo "Status report validation..."
	@$(call php, /bin/sh ./scripts/makefile/status-report-validation.sh)
else
	@echo "scripts/makefile/status-report-validation.sh file does not exist"
endif

## Validate drupal-rector
drupalrectorval:
ifneq ("$(wildcard rector.yml)","")
	@echo "Drupal Rector validation..."
	$(call php, composer install -o)
	$(call php, vendor/bin/rector -V)
	$(call php, vendor/bin/rector process --dry-run --no-progress-bar web/modules/custom web/themes/custom)
else
	@echo "rector.yml file does not exist"
endif

## Validate upgrade-status
upgradestatusval:
	@echo "Upgrade status validation..."
	@$(call php, /bin/sh ./scripts/makefile/upgrade-status-validation.sh)

## Validate newline at the end of files
newlineeof:
ifneq ("$(wildcard scripts/makefile/newlineeof.sh)","")
	@/bin/sh ./scripts/makefile/newlineeof.sh
else
	@echo "scripts/makefile/newlineeof.sh file does not exist"
endif

## Validate Behat scenarios
behat:
	@echo "Getting base url"
ifdef REVIEW_DOMAIN
	$(eval BASE_URL := $(MAIN_DOMAIN_NAME))
else
	$(eval BASE_URL := $(shell docker inspect --format='{{(index .NetworkSettings.Networks "$(COMPOSE_NET_NAME)").IPAddress}}' $(COMPOSE_PROJECT_NAME)_web))
endif
	echo "Base URL: " $(BASE_URL)
	if [ -z `docker ps -f 'name=$(COMPOSE_PROJECT_NAME)_chrome' --format '{{.Names}}'` ]; then \
		echo 'Browser driver is stoped. Running it.'; \
		make -s browser_driver; \
	fi
	@echo "Replacing URL_TO_TEST value in behat.yml with http://$(BASE_URL)"
	$(call php, cp behat.default.yml behat.yml)
	$(call php, sed -i "s/URL_TO_TEST/http:\/\/$(BASE_URL)/" behat.yml)
	@echo "Running Behat scenarios against http://$(BASE_URL)"
	$(call php, composer install -o)
	$(call php, vendor/bin/behat -V)
	$(call php, vendor/bin/behat --colors) || $(call php, vendor/bin/behat --colors --rerun)
	make browser_driver_stop

## List existing behat definitions
behatdl:
	$(call php, vendor/bin/behat -dl --colors)

## List existing behat definitions with more details
behatdi:
	$(call php, vendor/bin/behat -di --colors)

## Run browser driver for behat tests
browser_driver:
	docker run -d --init --rm --name $(COMPOSE_PROJECT_NAME)_chrome \
	--network container:$(COMPOSE_PROJECT_NAME)_php \
	$(IMAGE_DRIVER) \
	--remote-debugging-address=0.0.0.0 --remote-debugging-port=9222 --no-sandbox \
	--entrypoint "" chromium-browser --headless --disable-gpu \
	--window-size=1200,2080 \
	--disable-web-security --w3c=false

## Stop browser driver
browser_driver_stop:
	docker stop $(COMPOSE_PROJECT_NAME)_chrome

## Create a high number of random content
contentgen:
ifneq ("$(wildcard scripts/makefile/contentgen.sh)","")
	$(call php, composer install -o)
	@$(call php, /bin/sh ./scripts/makefile/contentgen.sh)
else
	@echo "scripts/makefile/watchdog-validation.sh file does not exist"
endif

## Run sniffer validations (executed as git hook, by scripts/git_hooks/sniffers.sh)
sniffers: | clang compval phpcs newlineeof

## Run all tests & validations (including sniffers)
tests: | sniffers cinsp drupalrectorval upgradestatusval behat watchdogval statusreportval

