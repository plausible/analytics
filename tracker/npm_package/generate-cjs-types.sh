#!/bin/bash

# Create CJS version of types by:
# 1. Removing export keywords
# 2. Adding module.exports at the end
sed -E '
# Remove export keywords
s/^export (function)/\1/;

# Add module.exports at the end
$a\
\
export = { init, track }
' plausible.d.ts > plausible.d.cts
