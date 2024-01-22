[logo]: https://www.authelia.com/images/branding/title.png "Authelia"
[![alt text][logo]](https://www.authelia.com/)

# authelia/buildkite
[![Docker Pulls](https://img.shields.io/docker/pulls/authelia/buildkite.svg)](https://hub.docker.com/r/authelia/buildkite/) [![Docker Stars](https://img.shields.io/docker/stars/authelia/buildkite.svg)](https://hub.docker.com/r/authelia/buildkite/)

The [buildkite agent](https://buildkite.com/docs/agent/v3) is a small, reliable and cross-platform build runner that makes it easy to run automated builds on your own infrastructure. Its main responsibilities are polling buildkite.com for work, running build jobs, reporting back the status code and output log of the job, and uploading the job's artifacts.

This custom image is based on the `docker:dind` to provide docker-in-docker alongside Buildkite to support the automated integration test cases run for Authelia's CI process.
The image will be re-built if any updates are made to the base `docker:dind` image.

This image shamelessly utilises the fine work by the team over at [LinuxServer.io](https://www.linuxserver.io/), credits to their [alpine baseimage](https://github.com/linuxserver/docker-baseimage-alpine/).
  
## Usage

Here are some example snippets to help you get started creating a container.

An example `docker-compose.yml` has also been provided in the repo which includes three nodes and a local registry cache.

### docker

```
docker create \
  --name=buildkite1 \
  -e BUILDKITE_AGENT_NAME=named-node-1 \
  -e BUILDKITE_AGENT_TOKEN=tokenhere \
  -e BUILDKITE_AGENT_TAGS=tags=here,moretags=here \
  -e BUILDKITE_AGENT_PRIORITY=priorityhere \
  -e PUID=1000 \
  -e PGID=1000 \
  -e TZ=Australia/Melbourne \
  -v <path to data>/ssh:/buildkite/.ssh \
  -v <path to data>/bundle:/buildkite/.bundle \
  -v <path to data>/cache:/buildkite/.cache \
  -v <path to data>/go:/buildkite/.go \
  -v <path to data>/pnpm-store:/buildkite/.local/share/pnpm/store \
  -v <path to data>/hooks:/buildkite/hooks \
  --restart unless-stopped \
  --privileged \
  authelia/buildkite
```
### docker-compose

Compatible with docker-compose v2 schemas.

```
---
version: "2.1"
services:
  buildkite1:
    image: authelia/buildkite
    container_name: buildkite1
    privileged: true
    volumes:
      - <path to data>/ssh:/buildkite/.ssh \
      - <path to data>/bundle:/buildkite/.bundle \
      - <path to data>/cache:/buildkite/.cache \
      - <path to data>/go:/buildkite/.go \
      - <path to data>/pnpm-store:/buildkite/.local/share/pnpm/store \
      - <path to data>/hooks:/buildkite/hooks
    restart: unless-stopped
    environment:
      - BUILDKITE_AGENT_NAME=named-node-1
      - BUILDKITE_AGENT_TOKEN=tokenhere
      - BUILDKITE_AGENT_TAGS=tags=here,moretags=here
      - BUILDKITE_AGENT_PRIORITY=priorityhere
      - PUID=1000
      - PGID=1000
      - TZ=Australia/Melbourne
```
## Parameters

Container images are configured using parameters passed at runtime (such as those above). These parameters are separated by a colon and indicate `<external>:<internal>` respectively. For example, `-p 8080:80` would expose port `80` from inside the container to be accessible from the host's IP on port `8080` outside the container.

|                     Parameter                     | Function                                                                                                                                                                                                                                                         |
|:-------------------------------------------------:|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
|      `-e BUILDKITE_AGENT_NAME=named-node-1`       | [agent name](https://buildkite.com/docs/agent/v3/configuration) for buildkite agent on specified node                                                                                                                                                            |
|       `-e BUILDKITE_AGENT_TOKEN=tokenhere`        | [agent token](https://buildkite.com/docs/agent/v3/tokens) for specified pipeline                                                                                                                                                                                 |
| `-e BUILDKITE_AGENT_TAGS=tags=here,moretags=here` | [agent tags](https://buildkite.com/docs/agent/v3/cli-start#setting-tags) on specified node, tag=value comma separated                                                                                                                                            |
|          `-e BUILDKITE_AGENT_PRIORITY=1`          | [agent priority](https://buildkite.com/docs/agent/v3/prioritization)                                                                                                                                                                                             |
|                  `-e PUID=1000`                   | for UserID - see below for explanation                                                                                                                                                                                                                           |
|                  `-e PGID=1000`                   | for GroupID - see below for explanation                                                                                                                                                                                                                          |
|            `-e TZ=Australia/Melbourne`            | for setting timezone information, eg Australia/Melbourne                                                                                                                                                                                                         |
|               `-v /buildkite/.ssh`                | SSH `id_rsa` and `ida_rsa.pub` stored here for [GitHub cloning](https://buildkite.com/docs/agent/v3/ssh-keys)                                                                                                                                                    |
|              `-v /buildkite/.cache`               | set this location to share cache for go-build and golangci-lint between multiple node containers                                                                                                                                                                 |
|                `-v /buildkite/.go`                | $GOPATH, set this location to share cache between multiple node containers                                                                                                                                                                                       |
|      `-v /buildkite/.local/share/pnpm/store`      | set this location to share pnpm cache between multiple node containers                                                                                                                                                                                           |
|               `-v /buildkite/hooks`               | Directory used to provide [agent based hooks](https://buildkite.com/docs/agent/v3/hooks) `/buildkite/hooks/environment` is used to provide secrets in to Buildkite such as `DOCKER_USERNAME` `DOCKER_PASSWORD` and `GITHUB_TOKEN` for publish and clean up steps |

## User / Group Identifiers

When using volumes (`-v` flags) permissions issues can arise between the host OS and the container, we avoid this issue by allowing you to specify the user `PUID` and group `PGID`.

Ensure any volume directories on the host are owned by the same user you specify and any permissions issues will vanish like magic.

In this instance `PUID=1000` and `PGID=1000`, to find yours use `id user` as below:

```
  $ id username
    uid=1000(dockeruser) gid=1000(dockergroup) groups=1000(dockergroup)
```

## Version
- **22/01/2024:** Fix user and group creation
- **17/01/2024:** Fix python dependencies
- **14/01/2024:** Update buildkite agent (v3.61.0), pnpm (v8.14.1), buildx (v0.12.1), reviewdog (v0.16.0), helm (v3.13.3), kubectl (v1.29.0)
- **06/12/2023:** Update buildkite agent (v3.60.1)
- **06/12/2023:** Update buildkite agent (v3.60.0), pnpm (v8.11.0), buildx (v0.11.2), s6-overlay (v3.1.6.2), helm (v3.13.2), kubectl (v1.28.4)
- **05/11/2023:** Update buildkite agent (v3.58.0), pnpm (v8.10.2), golangci-lint (v1.55.2), chart-testing (v3.10.1), chart-releaser (v1.6.1), helm (v3.13.1), kubectl (v1.28.3)
- **09/10/2023:** Update buildkite agent (v3.56.0), pnpm (v8.8.0), helm (v3.13.0), kubectl (v1.28.2)
- **17/09/2023:** Update buildkite agent (v3.55.0), pnpm (v8.7.5), golangci-lint (v1.54.2), reviewdog (v0.15.0), kubectl (v1.28.1)
- **18/08/2023:** Update buildkite agent (v3.52.0), ct (v3.9.0), cr (v1.6.0), helm (v3.12.3), kubectl (v1.28.0)
- **13/08/2023:** Update buildkite agent (v3.50.4), buildx (v0.11.2), pnpm (v8.6.12), golangci-lint (v1.54.1)
- **26/06/2023:** Update buildkite agent (v3.49.0), pnpm (v8.6.4), buildx (v0.11.0), golangci-lint (v1.53.3), reviewdog (v0.14.2), helm (v3.12.1) and kubectl (v1.27.3)
- **31/05/2023:** Update buildkite agent (v3.47.0), buildx (v0.10.5), pnpm (v8.6.0)
- **05/05/2023:** Update buildkite agent (v3.46.0), s6-overlay (v3.1.5.0)
- **03/05/2023:** Update s6-overlay (v3.1.4.2), pnpm (v8.4.0)
- **09/04/2023:** Update pnpm (v8.1.1)
- **07/04/2023:** Update golangci-lint (v1.52.2), ct (v3.8.0), helm (v3.11.2), kubectl (v1.26.3)
- **28/02/2023:** Update buildkite agent (v3.45.0), golangci-lint (v1.52.0), pnpm (v7.30.0)
- **19/03/2023:** Update buildkite agent (v3.45.0), golangci-lint (v1.52.0), pnpm (v7.30.0)
- **28/02/2023:** Update buildkite agent (v3.44.0), s6-overlay (v3.1.4.1), golangci-lint (v1.51.2)
- **03/02/2023:** Update buildkite agent (v3.43.1), pnpm (v7.26.3), buildx (v0.10.2), s6-overlay (v3.1.3.0), golangci-lint (v1.51.0), ct (v3.7.1), cr (v1.5.0), helm (v3.11.0), kubectl (v1.26.1)
- **07/12/2022:** Fix pnpm store path
- **09/09/2022:** Update buildx (v0.9.1), s6-overlay (v3.1.2.1), golangci-lint (v1.49.0), kubectl (v1.25.0)
- **12/08/2022:** Update to master tag of buildkit
- **07/08/2022:** Update pnpm (v7.9.0), golangci-lint (v1.48.0), ct (v3.7.0), helm (v3.9.2), kubectl (v1.24.3)
- **22/07/2022:** Update buildkite agent (v3.38.0), golangci-lint (v1.47.2)
- **12/07/2022:** Update buildkite agent (v3.37.0)
- **30/06/2022:** Update s6-overlay to v3.1.1.2.
- **21/06/2022:** Update s6-overlay to v3.1.1.0.
- **06/04/2022:** Update buildkite agent (v3.36.1), golangci-lint (v1.46.2)
- **06/05/2022:** Update s6-overlay to v3.1.0.1.
- **06/05/2022:** Add node tooling via npm instead of pnpm
- **04/05/2022:** Update reviewdog v0.14.1
- **16/04/2022:** Update reviewdog (v0.14.1-beta2, forked)
- **16/04/2022:** Update buildkite agent (v3.35.2)
- **16/04/2022:** Update reviewdog (v0.14.1-beta1, forked)
- **06/04/2022:** Update buildkite agent (v3.35.1)
- **30/03/2022:** Revert buildx to v0.7.1.
- **28/03/2022:** Update chart-releaser (v1.4.0).
- **25/03/2022:** Update golangci-lint (v1.45.2).
- **25/03/2022:** Update buildkite agent (v3.35.0).
- **24/03/2022:** Update golangci-lint (v1.45.1).
- **24/03/2022:** Update golangci-lint (v1.45.0).
- **18/03/2022:** Update buildkite agent (v3.34.1), pnpm (v6.32.3), buildx (v0.8.0), golangci-lint (v1.44.2), 
  reviewdog (v0.14.0), chart-testing (v3.5.1), helm (v3.8.1), kubectl (v1.23.5).
- **01/02/2022:** Revert s6-overlay to v2.2.0.3.
- **01/02/2022:** Bump s6-overlay to v3.0.0.2.
- **01/02/2022:** Revert s6-overlay to v2.2.0.3.
- **29/01/2022:** Update buildx and s6-overlay to v0.7.1 and v3.0.0.2 respectively.
- **29/01/2022:** Update golangci-lint, reviewdog, chart-testing, chart-releaser, helm, and kubectl to v1.44.0, v0.13.1,
  v3.5.0, v1.3.0, v3.8.0, and 1.23.3 respectively.
- **05/11/2021:** Update pnpm and golangci-lint v6.16 and v1.43.0
- **07/10/2021:** Add codecov uploader
- **30/09/2021:** Update buildkite-agent to v3.33.3
- **29/09/2021:** Update buildkite-agent to v3.33.2
- **29/09/2021:** Replace yarn with pnpm
- **28/09/2021:** Update buildkite-agent, helm and kubectl to v3.33.0, v3.7.0 and v1.22.2 respectively
- **21/09/2021:** Fix docker socket permissions issue on restart
- **20/09/2021:** Add musl cross-compilers for hardened binaries
- **16/09/2021:** Add buildx and set as default docker build command
- **15/09/2021:** Add /buildkite/.go/bin directory to $PATH
- **07/09/2021:** Update golangci-lint to v1.42.1
- **02/09/2021:** Update buildkite-agent to v3.32.3 and golangci-lint to v1.42.0
- **26/08/2021:** Update environment hook example
- **04/08/2021:** Add crun OCI runtime
- **02/08/2021:** Update buildkite-agent to v3.32.0 and helm to v3.6.3
- **23/07/2021:** Update reviewdog to v0.13.0 and kubectl to v1.21.3
- **07/07/2021:** Update buildkite-agent to v3.31.0
- **06/07/2021:** Add markdownlint cli and update helm to v3.6.2
- **28/06/2021:** Update reviewdog to v0.12.0
- **21/06/2021:** Update golangci-lint to v1.41.1, helm to v3.6.1, and kubectl to v1.21.2
- **17/06/2021:** Update golangci-lint to v1.41.0
- **01/06/2021:** Update buildkite-agent to v3.30.0, helm to v3.6.0, kubectl to v1.21.1, chart-testing to v3.4.0, and 
  chart-releaser to v1.2.1
- **27/04/2021:** Remove crun OCI runtime
- **27/04/2021:** Change entrypoint to dockerd to prevent TLS cert generation issue
- **22/04/2021:** Update buildkite-agent to v3.29.0 (and helm/kubectl to latest)
- **24/03/2021:** Update buildkite-agent to v3.28.1
- **04/03/2021:** Add Helm Chart Tools (helm, ct, cr, yamllint, yamale) and Refactor Layers
- **18/02/2021:** Update s6 to v2.2.0.3
- **18/02/2021:** Update golangci-lint to v1.37.0
- **11/02/2021:** Update buildkite-agent to v3.27.0
- **11/02/2021:** Include conventional-changelog-cli package for releases
- **02/02/2021:** Update s6 to v2.2.0.1
- **12/01/2021:** Update golangci-lint to v1.35.2
- **29/12/2020:** Update golangci-lint to v1.34.1
- **29/12/2020:** Include eslint package for frontend coverage
- **19/12/2020:** Install ruby bundler from alpine package repos
- **17/12/2020:** Include crun OCI runtime and set as Docker default
- **04/12/2020:** Update buildkite-agent to v3.26.0
- **24/11/2020:** Update golangci-lint to v1.33.0
- **18/11/2020:** Include nyc package for frontend coverage
- **10/11/2020:** Update golangci-lint to v1.32.2
- **26/10/2020:** Update s6 and reviewdog to v2.1.0.2 and v0.11.0 respectively
- **19/10/2020:** Update buildkite-agent to v3.24.0
- **19/10/2020:** Update s6 to v2.1.0.0
- **15/09/2020:** Update golangci-lint to v1.31.0
- **15/09/2020:** Update buildkite-agent to v3.23.1
- **06/09/2020:** Update buildkite-agent to v3.23.0
- **03/09/2020:** Update golangci-lint and reviewdog to v1.30.0 and v0.10.2 respectively
- **24/07/2020:** Update golangci-lint to v1.29.0
- **13/07/2020:** Update golangci-lint to v1.28.3
- **30/06/2020:** Update reviewdog to v0.10.1
- **19/06/2020:** Update buildkite-agent to v3.22.1
- **02/06/2020:** Include gnu variant of find
- **15/05/2020:** Update buildkite-agent to v3.22.0
- **14/05/2020:** Update golangci-lint to v1.27.0
- **08/05/2020:** Update reviewdog to v0.10.0
- **08/05/2020:** Update buildkite-agent to v3.21.1
- **05/05/2020:** Update buildkite-agent to v3.21.0
- **02/05/2020:** Update golangci-lint to v1.26.0
- **28/04/2020:** Update golangci-lint to v1.25.1
- **23/04/2020:** Update golangci-lint to v1.25.0
- **06/04/2020:** Include golangci-lint and reviewdog
- **02/04/2020:** Update chromium and chromedriver to 80.0.3987.132-r2
- **10/03/2020:** Set $BUNDLE_PATH for ruby
- **09/03/2020:** Include gnu variant of sed
- **28/02/2020:** Include ruby and bundler to generate doc website with Jekyll
- **12/02/2020:** Update buildkite-agent to v3.20.0
- **30/01/2020:** Update buildkite-agent to v3.19.0
- **29/01/2020:** Update buildkite-agent to v3.18.0
- **15/01/2020:** Include `/buildkite/hooks/environment` example and clarify hooks explanation
- **07/01/2020:** Pin chromium and chromedriver to 77.0.3865.120-r0
- **07/01/2020:** Include tar and zstd packages
- **19/12/2019:** Initial release
