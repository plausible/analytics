#!/bin/sh
# starts the db migration

BIN_DIR=$(dirname "$0")

"${BIN_DIR}"/bin/plausible eval Plausible.Release.interweave_migrate
