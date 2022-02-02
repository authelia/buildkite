#!/usr/bin/with-contenv bash

while [ ! -S "/run/docker.sock" ];
do
  sleep 1;
done
chown root:buildkite /run/docker.sock && \
s6-setuidgid buildkite docker buildx use buildx && \
s6-setuidgid buildkite docker buildx inspect --bootstrap && \
s6-setuidgid buildkite docker buildx use default && \
tail -f /dev/null
