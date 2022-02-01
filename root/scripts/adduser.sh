#!/bin/bash

echo "PUID: ${PUID}, PGID: ${PGID}"

groupmod -o -g "$PGID" buildkite
usermod -o -u "$PUID" buildkite

chown -R buildkite:buildkite /buildkite
