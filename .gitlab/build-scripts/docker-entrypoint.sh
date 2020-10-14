#!/bin/bash
set -e

chmod a+x /app/*.sh

if [[ "$1" = 'run' ]]; then
      exec gosu plausibleuser /app/bin/plausible start

elif [[ "$1" = 'db' ]]; then
      exec gosu plausibleuser /app/"$2".sh
 else
      exec "$@"

fi

exec "$@"

