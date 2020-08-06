#!/usr/bin/env sh

# installs newrelic.com agent extension

# use `php -i | grep "additional .ini"` to get it
PHP_INI_DIR=/etc/php7/conf.d

# get the latest version from https://download.newrelic.com/php_agent/archive/
NEW_RELIC_AGENT_VERSION="${NEW_RELIC_AGENT_VERSION:-9.12.0.268}"
# change it to 'linux' if docker image is not based on Alpinelinux
NEW_RELIC_LINUX=${NEW_RELIC_LINUX:-linux-musl}

set -e

env_vars='NEW_RELIC_APPNAME NEW_RELIC_LICENSE_KEY'

for var in $env_vars; do
	eval "val=\${$var}"
	if [ -z "${val}" -o "${val}" = 'x' ]; then
		echo "Configure ${var} in docker-compose.override.yml"
		echo "Visit https://newrelic.com 'Account settings' to get the key"; exit 1;
	fi
done

curl -L https://download.newrelic.com/php_agent/archive/${NEW_RELIC_AGENT_VERSION}/newrelic-php5-${NEW_RELIC_AGENT_VERSION}-${NEW_RELIC_LINUX}.tar.gz | tar -C /tmp -zx \
	&& export NR_INSTALL_USE_CP_NOT_LN=1 \
	&& export NR_INSTALL_SILENT=1 \
	&& /tmp/newrelic-php5-${NEW_RELIC_AGENT_VERSION}-${NEW_RELIC_LINUX}/newrelic-install install \
	&& rm -rf /tmp/newrelic-php5-* /tmp/nrinstall*

sed -i -e s/\"REPLACE_WITH_REAL_KEY\"/${NEW_RELIC_LICENSE_KEY}/ \
	-e s/newrelic.appname[[:space:]]=[[:space:]].\*/newrelic.appname="${NEW_RELIC_APPNAME}"/ \
	$PHP_INI_DIR/newrelic.ini
#	-e s/\;newrelic.daemon.address[[:space:]]=[[:space:]].\*/newrelic.daemon.address="${NEW_RELIC_DAEMON_ADDRESS}"/ \
