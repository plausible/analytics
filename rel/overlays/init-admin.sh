#!/bin/sh
# Create an admin user

BIN_DIR=$(dirname "$0")

"${BIN_DIR}"/bin/plausible eval Plausible.Release.init_admin
