#!/usr/bin/env sh

# installs newrelic.com agent extension

# use `php -i | grep "additional .ini"` to get it
PHP_INI_DIR=/etc/php83/conf.d

# get the latest version from https://download.newrelic.com/php_agent/archive/
NEW_RELIC_AGENT_VERSION="${NEW_RELIC_AGENT_VERSION:-10.22.0.12}"
# change it to 'linux' if docker image is not based on Alpinelinux
NEW_RELIC_LINUX=${NEW_RELIC_LINUX:-linux-musl}

set -e

# Print help in case parameters are empty
if [ -z "$1" ] || [ -z "$2" ]
then
	echo "Visit https://newrelic.com 'Account settings' to get the license key";
	exit 1 # Exit script after printing help
fi
NEW_RELIC_LICENSE_KEY="$1"
NEW_RELIC_APPNAME="$2"

curl -L https://download.newrelic.com/php_agent/archive/${NEW_RELIC_AGENT_VERSION}/newrelic-php5-${NEW_RELIC_AGENT_VERSION}-${NEW_RELIC_LINUX}.tar.gz | tar -C /tmp -zx \
	&& export NR_INSTALL_USE_CP_NOT_LN=1 \
	&& export NR_INSTALL_SILENT=1 \
	&& /tmp/newrelic-php5-${NEW_RELIC_AGENT_VERSION}-${NEW_RELIC_LINUX}/newrelic-install install \
	&& rm -rf /tmp/newrelic-php5-* /tmp/nrinstall*

sed -i -e s/\"REPLACE_WITH_REAL_KEY\"/${NEW_RELIC_LICENSE_KEY}/ \
	-e s/newrelic.appname[[:space:]]=[[:space:]].\*/newrelic.appname="${NEW_RELIC_APPNAME}"/ \
	$PHP_INI_DIR/newrelic.ini
#	-e s/\;newrelic.daemon.address[[:space:]]=[[:space:]].\*/newrelic.daemon.address="${NEW_RELIC_DAEMON_ADDRESS}"/ \

chgrp -R 1000 /var/log/newrelic
chmod -R g+w /var/log/newrelic
