#!/bin/sh
set -e

sleep 10
if echo "$@" | grep 'createdb' ; then
 /entrypoint.sh db createdb
fi
if echo "$@" | grep 'migrate' ; then
  /entrypoint.sh db migrate
fi
if echo "$@" | grep 'init-admin' ; then
  /entrypoint.sh db init-admin
fi

exec /entrypoint.sh run
