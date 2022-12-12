#!/usr/bin/env sh

NC='\x1b[0m'
RED='\x1b[31;01m'
GREEN='\x1b[32;01m'
YELLOW='\x1b[33;01m'

ACTION="${1:-na}"

xdebug_status() {
	if [ "$(php -m | grep -c 'Xdebug')" -eq "0" ]; then
		printf "%b disabled%b\n" "${GREEN}" "${NC}"
	else
		printf "%b enabled%b\n" "${GREEN}" "${NC}"
	fi
}

xdebug_find_file() {
	if [ -f /etc/php81/conf.d/50_xdebug.ini ]; then
		echo /etc/php81/conf.d/50_xdebug.ini
	elif [ -f /etc/php82/conf.d/50_xdebug.ini ]; then
		echo /etc/php82/conf.d/50_xdebug.ini
	elif [ -f /etc/php8/conf.d/50_xdebug.ini ]; then
		echo /etc/php8/conf.d/50_xdebug.ini
	else
		printf "%bXdebug ini file not found%b\n" "${RED}" "${NC}" && exit 1
	fi
}

xdebug_on() {
	printf "Enabling Xdebug..."

	if grep -q ';zend_extension' "$1"; then
		sed -i -e "s/;zend_extension/zend_extension/" "$1"
	else
		printf "%b already enabled%b\n" "${YELLOW}" "${NC}" && exit 0
	fi
}

xdebug_off() {
	printf "Disabling Xdebug..."

	if grep -q ';zend_extension' "$1"; then
		printf "%b already disabled%b\n" "${YELLOW}" "${NC}" && exit 0
	else
		sed -i -e "s/zend_extension/;zend_extension/" "$1"
	fi
}

xdebug_reload() {
	SCRIPT=$(readlink -f "$0")
	SCRIPTPATH=$(dirname "$SCRIPT")
	. "$SCRIPTPATH"/reload.sh
}

set -e

case "$ACTION" in
	on|off) xdebug_"$ACTION" "$(xdebug_find_file)" && xdebug_reload && xdebug_status ;;
	status) printf "Xdebug status..." && xdebug_status ;;
	*) printf "%bRequires [on|off|status] argument%b\n" "${RED}" "${NC}" && exit 1 ;;
esac
