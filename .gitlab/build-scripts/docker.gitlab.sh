#!/usr/bin/env bash

############################
function docker_create_config() {
############################
  mkdir -p /kaniko/.docker/
  echo "###############"
  echo "Logging into GitLab Container Registry with CI credentials for kaniko..."
  echo "###############"
  echo "{\"auths\":{\"$CI_REGISTRY\":{\"username\":\"$CI_REGISTRY_USER\",\"password\":\"$CI_REGISTRY_PASSWORD\"}}}" > /kaniko/.docker/config.json
  echo ""

}


############################
function docker_build_image() {
############################
  if [[ -f Dockerfile ]]; then
    echo "###############"
    echo "Building Dockerfile-based application..."
    echo "###############"

    /kaniko/executor \
      --cache=true \
      --context "${CI_PROJECT_DIR}" \
      --dockerfile "${CI_PROJECT_DIR}"/Dockerfile \
      --destination "${CI_REGISTRY_IMAGE}:${CI_COMMIT_REF_SLUG}-${CI_COMMIT_SHORT_SHA}"  \
      --destination "${CI_REGISTRY_IMAGE}:${CI_COMMIT_REF_SLUG}-latest"  \
      \
      "$@"

  else
    echo "No Dockerfile found."
    return 1
  fi
}
