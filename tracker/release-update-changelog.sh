#!/bin/bash

if [ -z "$1" ]; then
    echo "Usage: $0 <version>"
    exit 1
fi

version=$1
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

mv "$temp_file" CHANGELOG.md
