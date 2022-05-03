COMMIT=$(git rev-parse HEAD)
VERSION="$1"

if [ "$VERSION" = "" ]
then
  echo "Please supply a version tag e.g \`./rel/prepare_release.sh v1.5.0\`"
  exit 1
fi


if [ "$GITHUB_WORKSPACE" != "" ]
then
  TARGET=$GITHUB_WORKSPACE/priv/static/version.json
else
  TARGET=$(pwd)/priv/static/version.json
fi

echo $TARGET
echo "{\"version\": \"$VERSION\", \"commit\": \"$COMMIT\"}" > $TARGET
