## Run sniffer validations (executed as git hook, by scripts/git_hooks/sniffers.sh)
sniffers: | clang compval phpcs newlineeof

## Run all tests & validations (including sniffers)
tests: | sniffers cinsp drupalrectorval upgradestatusval behat watchdogval statusreportval patchval


# Function for code sniffer images.
phpcsexec = docker run --rm \
	-v $(CURDIR)/web/modules/custom:/work/modules \
	-v $(CURDIR)/web/themes/custom:/work/themes \
	skilldlabs/docker-phpcs-drupal ${1} -s --colors \
	--standard=Drupal,DrupalPractice \
	--extensions=php,module,inc,install,profile,theme,yml,txt,md,js \
	--ignore=*.min.js,*.css,libraries/*,dist/*,styleguide/*,README.md,README.txt,node_modules/*,work/themes/**.js,work/themes/**.md \
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
	@exit 1
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
	@exit 1
endif

## Validate configuration schema
cinsp:
ifneq ("$(wildcard scripts/makefile/config-inspector-validation.sh)","")
	@echo "Config schema validation..."
	$(call php, composer install -o)
	@$(call php, /bin/sh ./scripts/makefile/config-inspector-validation.sh)
else
	@echo "scripts/makefile/config-inspector-validation.sh file does not exist"
	@exit 1
endif

## Validate composer.json file
compval:
	@echo "Composer.json validation..."
	@docker run --rm -v $(CURDIR):/mnt -w /mnt $(IMAGE_PHP) composer validate

## Validate watchdog logs
watchdogval:
ifneq ("$(wildcard scripts/makefile/watchdog-validation.sh)","")
	@echo "Watchdog validation..."
	@$(call php, /bin/sh ./scripts/makefile/watchdog-validation.sh)
else
	@echo "scripts/makefile/watchdog-validation.sh file does not exist"
	@exit 1
endif

## Validate status report
statusreportval:
ifneq ("$(wildcard scripts/makefile/status-report-validation.sh)","")
	@echo "Status report validation..."
	@$(call php, /bin/sh ./scripts/makefile/status-report-validation.sh)
else
	@echo "scripts/makefile/status-report-validation.sh file does not exist"
	@exit 1
endif

## Validate drupal-rector
drupalrectorval:
ifneq ("$(wildcard rector.php)","")
	@echo "Drupal Rector validation..."
	$(call php, composer install -o)
	$(call php, vendor/bin/rector -V)
	$(call php, vendor/bin/rector process --dry-run --no-progress-bar web/modules/custom web/themes/custom)
else
	@echo "rector.php file does not exist"
	@exit 1
endif

## Validate upgrade-status
upgradestatusval:
ifneq ("$(wildcard scripts/makefile/upgrade-status-validation.sh)","")
	@echo "Upgrade status validation..."
	$(call php, composer install -o)
	@$(call php, /bin/sh ./scripts/makefile/upgrade-status-validation.sh)
else
	@echo "scripts/makefile/upgrade-status-validation.sh file does not exist"
	@exit 1
endif

## Validate newline at the end of files
newlineeof:
ifneq ("$(wildcard scripts/makefile/newlineeof.sh)","")
	@/bin/sh ./scripts/makefile/newlineeof.sh
else
	@echo "scripts/makefile/newlineeof.sh file does not exist"
	@exit 1
endif

## Validate that no custom patch is added to repo
patchval:
ifneq ("$(wildcard scripts/makefile/patchval.sh)","")
	@echo "Patch validation..."
	@$(call php-0, apk add --no-cache -q jq)
	@$(call php, /bin/sh ./scripts/makefile/patchval.sh)
else
	@echo "scripts/makefile/patchval.sh file does not exist"
	@exit 1
endif

## Validate Behat scenarios
BEHAT_ARGS ?= --colors
behat:
	@echo "Getting base url"
ifdef REVIEW_DOMAIN
	$(eval BASE_URL := https:\/\/$(RA_BASIC_AUTH_USERNAME):$(RA_BASIC_AUTH_PASSWORD)@$(MAIN_DOMAIN_NAME))
else
	$(eval BASE_URL := http:\/\/$(shell docker inspect --format='{{(index .NetworkSettings.Networks "$(COMPOSE_NET_NAME)").IPAddress}}' $(COMPOSE_PROJECT_NAME)_web))
endif
	echo "Base URL: " $(BASE_URL)
	if [ -z `docker ps -f 'name=$(COMPOSE_PROJECT_NAME)_chrome' --format '{{.Names}}'` ]; then \
		echo 'Browser driver is stoped. Running it.'; \
		make -s browser_driver; \
	fi
	@echo "Replacing URL_TO_TEST value in behat.yml with http://$(BASE_URL)"
	$(call php, cp behat.default.yml behat.yml)
	$(call php, sed -i "s/URL_TO_TEST/$(BASE_URL)/g" behat.yml)
	@echo "Running Behat scenarios against http://$(BASE_URL)"
	$(call php, composer install -o)
	$(call php, vendor/bin/behat -V)
	$(call php, vendor/bin/behat $(BEHAT_ARGS)) || $(call php, vendor/bin/behat $(BEHAT_ARGS) --rerun)
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
	--entrypoint "" \
	$(IMAGE_DRIVER) \
	chromium-browser --headless --disable-gpu \
	--remote-debugging-address=0.0.0.0 --remote-debugging-port=9222 --no-sandbox \
	--window-size=1200,2080 \
	--disable-web-security --w3c=false

## Stop browser driver
browser_driver_stop:
	@echo 'Stopping browser driver...'
	if [ ! -z `docker ps -f 'name=$(COMPOSE_PROJECT_NAME)_chrome' --format '{{.Names}}'` ]; then \
		docker stop $(COMPOSE_PROJECT_NAME)_chrome; \
	fi

## Create a high number of random content
contentgen:
ifneq ("$(wildcard scripts/makefile/contentgen.sh)","")
	$(call php, composer install -o)
	@$(call php, /bin/sh ./scripts/makefile/contentgen.sh)
else
	@echo "scripts/makefile/watchdog-validation.sh file does not exist"
	@exit 1
endif

blackfire:
ifneq ("$(wildcard scripts/makefile/blackfire.sh)","")
	$(call php-0, /bin/sh ./scripts/makefile/blackfire.sh)
	$(call php-0, /bin/sh ./scripts/makefile/reload.sh)
	@echo "Blackfire extension enabled"
else
	@echo "scripts/makefile/blackfire.sh file does not exist"
	@exit 1
endif

newrelic:
ifdef NEW_RELIC_LICENSE_KEY
	$(call php-0, /bin/sh ./scripts/makefile/newrelic.sh $(NEW_RELIC_LICENSE_KEY) '$(COMPOSE_PROJECT_NAME)')
	$(call php, sed -i -e 's/#  <<: \*service-newrelic/  <<: \*service-newrelic/g' docker/docker-compose.override.yml)
	$(call php-0, /bin/sh ./scripts/makefile/reload.sh)
	@echo "NewRelic PHP extension enabled"
else
	@echo "NewRelic install skipped as NEW_RELIC_LICENSE_KEY is not set"
endif

xdebug:
	$(call php-0, /bin/sh ./scripts/makefile/xdebug.sh $(filter-out $@, $(MAKECMDGOALS)))
