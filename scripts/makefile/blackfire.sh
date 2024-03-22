#!/usr/bin/env sh

# installs backfire/io probe extension

# use `php -i | grep "additional .ini"` to get it
PHP_INI_DIR=/etc/php83/conf.d

set -e

env_vars='BLACKFIRE_CLIENT_ID BLACKFIRE_CLIENT_TOKEN'

for var in $env_vars; do
	eval "val=\${$var}"
	if [ -z "${val}" -o "${val}" = 'x' ]; then
		echo "Configure ${var} in docker-compose.override.yml"
		echo "Visit https://blackfire.io/my/settings/credentials to get credentials"; exit 1
	fi
done

version=$(php -r "echo PHP_MAJOR_VERSION.PHP_MINOR_VERSION;") \
	&& curl -A "Docker" -o /tmp/blackfire-probe.tar.gz -D - -L -s https://blackfire.io/api/v1/releases/probe/php/alpine/amd64/$version \
	&& mkdir -p /tmp/blackfire \
	&& tar zxpf /tmp/blackfire-probe.tar.gz -C /tmp/blackfire \
	&& mv /tmp/blackfire/blackfire-*.so $(php -r "echo ini_get ('extension_dir');")/blackfire.so \
	&& printf "extension=blackfire.so\nblackfire.agent_socket=tcp://blackfire:8707\n" > $PHP_INI_DIR/blackfire.ini \
	&& rm -rf /tmp/blackfire /tmp/blackfire-probe.tar.gz
