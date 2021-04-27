FROM docker:dind

# set labels
LABEL maintainer="Nightah"

# set application versions
ARG ARCH="amd64"
ARG BUILDKITE_VERSION="3.29.0"
ARG OVERLAY_VERSION="v2.2.0.3"
ARG GOLANGCILINT_VERSION="v1.39.0"
ARG REVIEWDOG_VERSION="v0.11.0"
ARG CT_VERSION="3.3.1"
ARG CR_VERSION="1.2.0"
ARG HELM_VERSION="v3.5.4"
ARG KUBECTL_VERSION="v1.21.0"

# environment variables
ENV PS1="$(whoami)@$(hostname):$(pwd)$ " \
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
   curl -Lfs -o /usr/local/bin/ssh-env-config.sh https://raw.githubusercontent.com/buildkite/docker-ssh-env-config/master/ssh-env-config.sh && \
   chmod +x /usr/local/bin/ssh-env-config.sh && \
   curl -Lfs -o buildkite-agent.tar.gz https://github.com/buildkite/agent/releases/download/v${BUILDKITE_VERSION}/buildkite-agent-linux-${ARCH}-${BUILDKITE_VERSION}.tar.gz && \
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
     chromium@edge \
     chromium-chromedriver@edge \
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
     yarn@edge \
     zlib-dev \
     zstd

RUN \
 echo "**** Add Python Packages ****" && \
   pip install yamllint yamale && \
 echo "**** Add s6 overlay ****" && \
   cd /tmp && \
   curl -Lfs -o s6-overlay.tar.gz "https://github.com/just-containers/s6-overlay/releases/download/${OVERLAY_VERSION}/s6-overlay-${ARCH}.tar.gz" && \
   tar xfz s6-overlay.tar.gz -C / && \
 echo "**** Add k8s/helm tools ****" && \
   curl -Lfs -o ct.tar.gz "https://github.com/helm/chart-testing/releases/download/v${CT_VERSION}/chart-testing_${CT_VERSION}_linux_${ARCH}.tar.gz" && \
   curl -Lfs -o cr.tar.gz "https://github.com/helm/chart-releaser/releases/download/v${CR_VERSION}/chart-releaser_${CR_VERSION}_linux_${ARCH}.tar.gz" && \
   curl -Lfs -o helm.tar.gz "https://get.helm.sh/helm-${HELM_VERSION}-linux-${ARCH}.tar.gz" && \
   curl -LfsO "https://storage.googleapis.com/kubernetes-release/release/${KUBECTL_VERSION}/bin/linux/${ARCH}/kubectl" && \
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
 echo "**** Install Linting tools ****" && \
   curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s -- -b /bin ${GOLANGCILINT_VERSION} && \
   curl -sfL https://raw.githubusercontent.com/reviewdog/reviewdog/master/install.sh| sh -s -- -b /bin ${REVIEWDOG_VERSION} && \
   yarn global add eslint && \
 echo "**** Install Coverage tools ****" && \
   yarn global add nyc && \
 echo "**** Install Release tools ****" && \
   yarn global add conventional-changelog-cli && \
 echo "**** Cleanup ****" && \
   rm -rf /tmp/*

# ports and volumes
VOLUME /buildkite

ENTRYPOINT ["/init"]
