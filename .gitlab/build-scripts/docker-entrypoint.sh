#!/bin/sh

set -e

# Confirm database exists in the required state
/app/createdb.sh
/app/migrate.sh

# Start Plausible
/app/bin/plausible start
