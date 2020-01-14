#!/bin/bash

cp -r /data/buildkite/.docker /buildkite/.docker
cp -r /data/buildkite/hooks /buildkite/hooks

chmod 777 /tmp

/init
