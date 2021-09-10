#!/usr/bin/env bash
set -u

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
    concurrency: 1
    concurrency_group: "deployments"
    agents:
      upload: "fast"
    if: build.branch == "master"

  - label: ":docker: Build and Deploy"
    commands:
      - "docker build --tag ${REPOSITORY}:${TAG} --no-cache=true --pull=true ."
      - "docker push ${REPOSITORY}:${TAG}"
    agents:
      upload: "fast"
    if: build.branch != "master"

  - wait:
    if: build.branch == "master"

  - label: ":docker: Update README.md"
    command: "curl \"https://ci.nerv.com.au/readmesync/update?github_repo=${REPOSITORY}&dockerhub_repo=${REPOSITORY}\""
    if: build.branch == "master"
    agents:
      upload: "fast"
EOF