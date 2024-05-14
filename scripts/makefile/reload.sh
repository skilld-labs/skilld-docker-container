#!/usr/bin/env sh

NC='\x1b[0m'
RED='\x1b[31;01m'
GREEN='\x1b[32;01m'
YELLOW='\x1b[33;01m'

set -e

socket='--unix-socket /run/control.unit.sock'
sapi=$(cat /proc/1/comm)
file=${1:-/var/lib/unit/conf.json}

if [ $sapi == unitd ]; then
	if [ -z "$1" ]; then
		# just reload as no new config passed
		curl -s -o /dev/null $socket http://localhost/control/applications/drupal/restart
	else
		curl -s -o /dev/null -X PUT --data-binary @$file $socket http://localhost/config
	fi
elif [ $sapi == php-fpm* ]; then
	kill -USR2 1;
else
	printf "%b unknown SAPI to restart%b\n" "${RED}" "${NC}" && exit 1
fi
