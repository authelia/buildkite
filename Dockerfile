FROM docker:dind

# set labels
LABEL maintainer="Nightah"

# set application versions
ARG ARCH="amd64"
ARG BUILDKITE_VERSION="3.33.3"
ARG PNPM_VERSION="v6.28"
ARG BUILDX_VERSION="v0.7.1"
ARG CC_VERSION="v15"
ARG OVERLAY_VERSION="v3.0.0.2"
ARG GOLANGCILINT_VERSION="v1.44.0"
ARG REVIEWDOG_VERSION="v0.13.1"
ARG CT_VERSION="3.5.0"
ARG CR_VERSION="1.3.0"
ARG HELM_VERSION="v3.8.0"
ARG KUBECTL_VERSION="v1.23.3"

# environment variables
ENV PATH="$PATH:/buildkite/.go/bin" \
PS1="$(whoami)@$(hostname):$(pwd)$ " \
HOME="/buildkite" \
TERM="xterm"

# set runtime variables
ENV BUILDKITE_AGENT_CONFIG="/buildkite/buildkite-agent.cfg" \
BUNDLE_PATH="/buildkite/.gem" \
GOPATH="/buildkite/.go"

# add local files
COPY root/ /

# add packages required to install others
RUN \
  echo "**** Install Essential Packages ****" && \
    apk add --no-cache \
      curl \
      sed \
      tar

# add buildkite
RUN \
  echo "**** Install Buildkite ****" && \
    mkdir -p /buildkite/builds /buildkite/hooks /buildkite/plugins && \
    curl -sSfL -o /usr/local/bin/ssh-env-config.sh "https://raw.githubusercontent.com/buildkite/docker-ssh-env-config/master/ssh-env-config.sh" && \
    chmod +x /usr/local/bin/ssh-env-config.sh && \
    curl -sSfL -o buildkite-agent.tar.gz "https://github.com/buildkite/agent/releases/download/v${BUILDKITE_VERSION}/buildkite-agent-linux-${ARCH}-${BUILDKITE_VERSION}.tar.gz" && \
    tar xf buildkite-agent.tar.gz && \
    sed -i 's/token=/#token=/g' buildkite-agent.cfg && \
    sed -i 's/\$HOME\/.buildkite-agent/\/buildkite/g' buildkite-agent.cfg && \
    mv buildkite-agent.cfg /buildkite/buildkite-agent.cfg && \
    mv buildkite-agent /usr/local/bin/buildkite-agent

# modifications
RUN \
  echo "**** Install Authelia CI pre-requisites ****" && \
    echo "@edge http://dl-cdn.alpinelinux.org/alpine/edge/community" >> /etc/apk/repositories && \
    echo "@edget http://dl-cdn.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories && \
    apk add --no-cache \
      bash \
      ca-certificates \
      coreutils \
      chromium \
      chromium-chromedriver \
      crun@edge \
      docker-compose \
      findutils \
      g++ \
      gettext \
      git \
      hub@edget \
      go@edge \
      jq \
      libc6-compat \
      libstdc++ \
      make \
      nodejs \
      npm \
      openssh-client \
      perl \
      py3-pip \
      py3-wheel \
      python3 \
      rsync \
      ruby-bigdecimal \
      ruby-bundler \
      ruby-dev \
      ruby-json \
      shadow \
      sudo \
      tzdata \
      zlib-dev \
      zstd

RUN \
  echo "**** Add pnpm ****" && \
    curl -f https://get.pnpm.io/${PNPM_VERSION}.js | node - add --global pnpm && \
    pnpm config set --global store-dir ~/.pnpm-store && \
  echo "**** Add Python Packages ****" && \
    pip install yamllint yamale && \
  echo "**** Add s6 overlay ****" && \
    cd /tmp && \
    curl -sSfL -o s6-overlay.tar.gz "https://github.com/just-containers/s6-overlay/releases/download/${OVERLAY_VERSION}/s6-overlay-${ARCH}.tar.gz" && \
    tar xfz s6-overlay.tar.gz -C / && \
  echo "**** Add musl cross-compilers ****" && \
    curl -sSfL "https://github.com/just-containers/musl-cross-make/releases/download/${CC_VERSION}/gcc-9.2.0-arm-linux-musleabihf.tar.xz" | tar -xJ --directory / && \
    curl -sSfL "https://github.com/just-containers/musl-cross-make/releases/download/${CC_VERSION}/gcc-9.2.0-aarch64-linux-musl.tar.xz" | tar -xJ --directory / && \
  echo "**** Add k8s/helm tools ****" && \
    curl -SsLf -o ct.tar.gz "https://github.com/helm/chart-testing/releases/download/v${CT_VERSION}/chart-testing_${CT_VERSION}_linux_${ARCH}.tar.gz" && \
    curl -SsLf -o cr.tar.gz "https://github.com/helm/chart-releaser/releases/download/v${CR_VERSION}/chart-releaser_${CR_VERSION}_linux_${ARCH}.tar.gz" && \
    curl -sSLf -o helm.tar.gz "https://get.helm.sh/helm-${HELM_VERSION}-linux-${ARCH}.tar.gz" && \
    curl -sSLfO "https://storage.googleapis.com/kubernetes-release/release/${KUBECTL_VERSION}/bin/linux/${ARCH}/kubectl" && \
    tar xfz ct.tar.gz -C /tmp && \
    tar xfz cr.tar.gz -C /tmp && \
    tar xfz helm.tar.gz -C /tmp && \
    chmod +x ct cr linux-${ARCH}/helm kubectl && \
    mv -t /usr/local/bin/ ct cr linux-${ARCH}/helm kubectl && \
    mkdir /etc/ct && \
    mv -t /etc/ct/ etc/chart_schema.yaml etc/lintconf.yaml && \
  echo "**** Patch CVE-2019-5021 ****" && \
    sed -i -e 's/^root::/root:!:/' /etc/shadow && \
  echo "**** Create buildkite user and make our folders ****" && \
    useradd -u 911 -U -d /buildkite -s /bin/false buildkite && \
    usermod -G wheel buildkite && \
    sed -i 's/# %wheel/%wheel/g' /etc/sudoers && \
  echo "**** Add buildx and set as default ****" && \
    mkdir -p /buildkite/.docker/cli-plugins && \
    curl -sSfL -o /buildkite/.docker/cli-plugins/docker-buildx "https://github.com/docker/buildx/releases/download/${BUILDX_VERSION}/buildx-${BUILDX_VERSION}.linux-amd64" && \
    chmod +x /buildkite/.docker/cli-plugins/docker-buildx && \
    docker buildx install && \
    docker buildx create --name buildx && \
  echo "**** Install Linting tools ****" && \
    curl -sSfL "https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh" | sh -s -- -b /bin ${GOLANGCILINT_VERSION} && \
    curl -sSfL "https://raw.githubusercontent.com/reviewdog/reviewdog/master/install.sh" | sh -s -- -b /bin ${REVIEWDOG_VERSION} && \
    pnpm add --global eslint markdownlint-cli && \
  echo "**** Install Coverage tools ****" && \
    curl -sSfL -o /usr/local/bin/codecov "https://uploader.codecov.io/latest/alpine/codecov" && \
    chmod +x /usr/local/bin/codecov && \
    pnpm add --global nyc && \
  echo "**** Install Release tools ****" && \
    pnpm add --global conventional-changelog-cli && \
  echo "**** Cleanup ****" && \
    rm -rf /tmp/* /buildkite/.pnpm-store

# ports and volumes
VOLUME /buildkite

ENTRYPOINT ["/init"]
