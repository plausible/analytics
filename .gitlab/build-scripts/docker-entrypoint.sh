#!/bin/bash
set -e

if [[ "$1" = 'run' ]]; then
      /app/bin/plausible start

elif [[ "$1" = 'db' ]]; then
      /app/"$2".sh
fi

exec "$@"

