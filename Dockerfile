FROM docker:dind

# set labels
LABEL maintainer="Nightah"

# set application versions
ARG ARCH="amd64"
ARG ARCH_ALT="x86_64"
ARG BUILDKITE_VERSION="3.103.1"
ARG PNPM_VERSION="10.14.0"
ARG BUILDX_VERSION="0.26.1"
ARG CC_TRIPLES="aarch64-unknown-linux-musl,arm-unknown-linux-musleabihf"
ARG CC_VERSION="20250206"
ARG OVERLAY_VERSION="3.2.1.0"
ARG GOLANGCILINT_VERSION="2.4.0"
ARG GITLEAKS_VERSION="8.28.0"
ARG REVIEWDOG_VERSION="0.20.3"
ARG CT_VERSION="3.13.0"
# Authelia fork
ARG CR_VERSION="1.6.1"
ARG HELM_VERSION="3.18.5"
ARG KUBECTL_VERSION="1.33.4"

# environment variables
ENV PATH="$PATH:/buildkite/.go/bin" \
PS1="$(whoami)@$(hostname):$(pwd)$ " \
HOME="/buildkite" \
S6_CMD_WAIT_FOR_SERVICES_MAXTIME="0" \
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
      crun \
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
      yamllint \
      python3 \
      rsync \
      shadow \
      sudo \
      tzdata \
      zlib-dev \
      zstd

RUN \
  cd /tmp && \
  echo "**** Add Python Packages ****" && \
    pip install yamale --break-system-packages && \
  echo "**** Add pnpm ****" && \
    npm add --global pnpm@${PNPM_VERSION} && \
  echo "**** Add s6 overlay ****" && \
    curl -sSfL -o s6-overlay-noarch.tar.xz "https://github.com/just-containers/s6-overlay/releases/download/v${OVERLAY_VERSION}/s6-overlay-noarch.tar.xz" && \
    curl -sSfL -o s6-overlay.tar.xz "https://github.com/just-containers/s6-overlay/releases/download/v${OVERLAY_VERSION}/s6-overlay-${ARCH_ALT}.tar.xz" && \
    tar -C / -Jpxf s6-overlay-noarch.tar.xz && \
    tar -C / -Jpxf s6-overlay.tar.xz && \
  echo "**** Add musl cross-compilers ****" && \
    for triple in $(echo ${CC_TRIPLES} | tr "," " "); do \
      curl -sSfL "https://github.com/cross-tools/musl-cross/releases/download/${CC_VERSION}/${triple}.tar.xz" | tar -C / -xJ; \
      for bin in /${triple}/bin/*; do \
        ln -s "${bin}" "/bin/$(basename ${bin//-unknown})"; \
      done; \
    done && \
  echo "**** Add k8s/helm tools ****" && \
    curl -SsLf -o ct.tar.gz "https://github.com/helm/chart-testing/releases/download/v${CT_VERSION}/chart-testing_${CT_VERSION}_linux_${ARCH}.tar.gz" && \
    curl -SsLf -o cr.tar.gz "https://github.com/authelia/chart-releaser/archive/refs/tags/v${CR_VERSION}.tar.gz" && \
    curl -sSLf -o helm.tar.gz "https://get.helm.sh/helm-v${HELM_VERSION}-linux-${ARCH}.tar.gz" && \
    curl -sSLfO "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/${ARCH}/kubectl" && \
    tar xfz ct.tar.gz -C /tmp && \
    tar xfz cr.tar.gz -C /tmp && \
    tar xfz helm.tar.gz -C /tmp && \
    cd chart-releaser-${CR_VERSION} && \
    go mod download && \
    go build -o /tmp/cr ./cr && \
    cd /tmp && \
    chmod +x ct cr linux-${ARCH}/helm kubectl && \
    mv -t /usr/local/bin/ ct cr linux-${ARCH}/helm kubectl && \
    mkdir -p /etc/ct && \
    mv -t /etc/ct/ etc/chart_schema.yaml etc/lintconf.yaml && \
  echo "**** Patch CVE-2019-5021 ****" && \
    sed -i -e 's/^root::/root:!:/' /etc/shadow && \
  echo "**** Create buildkite user and make our folders ****" && \
    useradd -u 911 -U -d /buildkite -s /bin/false buildkite && \
    usermod -aG docker,wheel buildkite && \
    sed -i 's/# %wheel/%wheel/g' /etc/sudoers && \
  echo "**** Add buildx ****" && \
    mkdir -p /buildkite/.docker/cli-plugins && \
    curl -sSfL -o /buildkite/.docker/cli-plugins/docker-buildx "https://github.com/docker/buildx/releases/download/v${BUILDX_VERSION}/buildx-v${BUILDX_VERSION}.linux-amd64" && \
    chmod +x /buildkite/.docker/cli-plugins/docker-buildx && \
    docker buildx install && \
  echo "**** Install Linting tools ****" && \
    curl -sSfL "https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh" | sh -s -- -b /bin v${GOLANGCILINT_VERSION} && \
    curl -sSfL "https://raw.githubusercontent.com/reviewdog/reviewdog/master/install.sh" | sh -s -- -b /bin v${REVIEWDOG_VERSION} && \
    curl -sSfL -o gitleaks.tar.gz "https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION}_linux_x64.tar.gz" && \
    tar xfz gitleaks.tar.gz -C /usr/local/bin/ gitleaks && \
    npm add --global eslint@8.57.0 markdownlint-cli && \
  echo "**** Install Coverage tools ****" && \
    curl -sSfL -o /usr/local/bin/codecov "https://uploader.codecov.io/latest/alpine/codecov" && \
    chmod +x /usr/local/bin/codecov && \
    npm add --global nyc && \
  echo "**** Install Release tools ****" && \
    npm add --global conventional-changelog-cli && \
  echo "**** Cleanup ****" && \
    find /usr/local/bin/ -not -user root -exec chown root:root {} + && \
    rm -rf /tmp/* /buildkite/.pnpm-store

# ports and volumes
VOLUME /buildkite

ENTRYPOINT ["/init"]
