COMMIT=$(git rev-parse HEAD)
VERSION="$1"

if [ "$VERSION" = "" ]
then
  echo "Please supply a version tag e.g \`./rel/prepare_release.sh v1.5.0\`"
  exit 1
fi



echo "{\"version\": \"$VERSION\", \"commit\": \"$COMMIT\"}" > priv/static/version.json
