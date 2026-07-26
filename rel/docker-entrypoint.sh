#!/bin/sh
set -e

if [ "$(id -u)" = "0" ]; then
  data_dir="${DATA_DIR:-${DEFAULT_DATA_DIR:-/var/lib/plausible}}"
  mkdir -p "$data_dir"
  chown -R plausible:nogroup "$data_dir"
  exec su-exec plausible "$0" "$@"
fi

if [ "$1" = 'run' ]; then
  exec /app/bin/plausible start

elif [ "$1" = 'db' ]; then
  exec /app/"$2".sh
else
  exec "$@"
fi

exec "$@"
