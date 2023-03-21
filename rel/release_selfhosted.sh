VERSION="$1"
VERSION="${VERSION#[vV]}"
VERSION_MAJOR="${VERSION%%\.*}"
VERSION_MINOR="${VERSION#*.}"
VERSION_MINOR="${VERSION_MINOR%.*}"
VERSION_PATCH="${VERSION##*.}"

if [ "$VERSION" = "" ]
then
  echo "Please supply a version tag e.g \`./rel/selfhosted_release.sh v1.5.0\`"
  exit 1
fi

FULL_IMAGE="plausible/analytics:v${VERSION_MAJOR}.${VERSION_MINOR}.${VERSION_PATCH}"
MINOR_IMAGE="plausible/analytics:v${VERSION_MAJOR}.${VERSION_MINOR}"
MAJOR_IMAGE="plausible/analytics:v${VERSION_MAJOR}"
LATEST_IMAGE="plausible/analytics:latest"

echo "Here's the plan:"
echo "Build $FULL_IMAGE"
echo "Push $FULL_IMAGE"
echo "Push $MINOR_IMAGE"
echo "Push $MAJOR_IMAGE"
echo "Push $LATEST_IMAGE"

read -p "Continue (y/n)?" choice
case "$choice" in
  y|Y ) echo "Cool. Will continue";;
  * ) exit 1;;
esac

./rel/prepare_release.sh $1

echo "Building $FULL_IMAGE"

# docker build -t $FULL_IMAGE .

echo "Pushing $FULL_IMAGE"
# docker push $FULL_IMAGE

MINOR_IMAGE="plausible/analytics:v${VERSION_MAJOR}.${VERSION_MINOR}"
echo "Pushing $MINOR_IMAGE"
# docker tag $IMAGE $MINOR_IMAGE
# docker push $MINOR_IMAGE

MAJOR_IMAGE="plausible/analytics:v${VERSION_MAJOR}"
echo "Pushing $MAJOR_IMAGE"
# docker tag $IMAGE $MAJOR_IMAGE
# docker push $MAJOR_IMAGE

LATEST_IMAGE="plausible/analytics:latest"
echo "Pushing $LATEST_IMAGE"
# docker tag $IMAGE $LATEST_IMAGE
# docker push $LATEST_IMAGE
