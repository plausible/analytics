COMMIT=$(git rev-parse HEAD)
VERSION="$1"

if [ "$VERSION" = "" ]
then
  echo "Please supply a version tag e.g \`./rel/prepare_release.sh v1.5.0\`"
  exit 1
fi


if [ "$GITHUB_WORKSPACE" != "" ]
then
  ls $GITHUB_WORKSPACE
  TARGET_FOLDER=$GITHUB_WORKSPACE/priv
else
  TARGET_FOLDER=$(pwd)/priv
fi

echo "{\"version\": \"$VERSION\", \"commit\": \"$COMMIT\"}" > $TARGET_FOLDER/version.json

echo "ADDED VERSION INFO TO $TARGET_FOLDER/version.json"
cat $TARGET_FOLDER/version.json
