#!/usr/bin/env sh

NC='\x1b[0m'
RED='\x1b[31;01m'
GREEN='\x1b[32;01m'
YELLOW='\x1b[33;01m'

set -e

sapi=$(cat /proc/1/comm)

if [ $sapi = "unitd" ]; then
	socket='--unix-socket /run/control.unit.sock'
	if [ -z "$1" ]; then
		# just reload as no new config passed
		curl -s -o /dev/null $socket http://localhost/control/applications/drupal/restart
	else
		file=${1}/conf.json
		curl -s -o /dev/null -X PUT --data-binary @$file $socket http://localhost/config
	fi
elif [ $sapi = "frankenphp" ]; then
	frankenphp reload -c ${1:-/etc/caddy}/Caddyfile
elif echo "$sapi" | grep -q '^php-fpm'; then
	kill -USR2 1;
else
	printf "%b unknown SAPI to restart%b\n" "${RED}" "${NC}" && exit 1
fi
