#!/usr/bin/env sh
set -eu

php-fpm
/usr/sbin/sshd -D
exec nginx -g "daemon off;"
