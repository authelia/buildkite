#!/usr/bin/env bash

REPOSITORY="authelia/buildkite"

if [[ ${BUILDKITE_TAG} == "" ]]; then
  TAG="latest"
else
  TAG=${BUILDKITE_TAG}
fi

cat << EOF
steps:
  - label: ":docker: Build and Deploy"
    commands:
      - "docker build --tag ${REPOSITORY}:${TAG} --no-cache=true --pull=true ."
      - "docker push ${REPOSITORY}:${TAG}"
    agents:
      upload: "fast"

  - wait:
    if: build.branch == "master"

  - command: "curl \"https://ci.nerv.com.au/readmesync/update?github_repo=${REPOSITORY}&dockerhub_repo=${REPOSITORY}\""
    label: ":docker: Update README.md"
    if: build.branch == "master"
    agents:
      upload: "fast"
EOF