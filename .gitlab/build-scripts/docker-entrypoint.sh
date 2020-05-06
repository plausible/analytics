#!/bin/bash
set -e

if [ "$1" = 'run' ]; then
    exec gosu plausibleuser /app/bin/plausible start
fi

exec "$@"

