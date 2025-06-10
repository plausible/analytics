#!/bin/bash

# Ensure we're in the correct directory for relative paths to work
script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$script_dir"

version=$(jq -r .version npm_package/package.json)
release_date=$(date +%Y-%m-%d)

temp_file=$(mktemp)

# Copy header and add new unreleased section
head -n 6 CHANGELOG.md > "$temp_file"
cat >> "$temp_file" << EOF

## Unreleased

EOF

# Replace the old unreleased section with new version
sed "s/## Unreleased/## [$version] - $release_date/" CHANGELOG.md | \
    tail -n +8 >> "$temp_file"

mv "$temp_file" npm_package/CHANGELOG.md
