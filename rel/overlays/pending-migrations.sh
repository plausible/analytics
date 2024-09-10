#!/bin/sh
# lists pending migrations

BIN_DIR=$(dirname "$0")

"${BIN_DIR}"/bin/plausible eval Plausible.Release.pending_streaks
