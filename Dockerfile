FROM docker:dind

LABEL org.opencontainers.image.authors="Authelia Team <team@authelia.com>"

ARG ARCH="amd64"
ARG ARCH_ALT="x86_64"
ARG BUILDKITE_VERSION="3.107.0"
ARG BUILDX_VERSION="0.28.0"
# Authelia fork
ARG CR_VERSION="1.6.1"
ARG CT_VERSION="3.13.0"
ARG GOLANGCILINT_VERSION="2.4.0"
ARG GORELEASER_VERSION="2.12.2"
ARG GRYPE_VERSION="0.100.0"
ARG HELM_VERSION="3.19.0"
ARG KUBECTL_VERSION="1.33.4"
ARG OVERLAY_VERSION="3.2.1.0"
ARG PNPM_VERSION="10.17.0"
ARG REVIEWDOG_VERSION="0.21.0"
ARG SYFT_VERSION="1.33.0"

ENV \
	PATH="$PATH:/buildkite/.go/bin" \
	PS1="$(whoami)@$(hostname):$(pwd)$ " \
	HOME="/buildkite" \
	S6_CMD_WAIT_FOR_SERVICES_MAXTIME="0" \
	TERM="xterm"

ENV \
	BUILDKITE_AGENT_CONFIG="/buildkite/buildkite-agent.cfg" \
	GOPATH="/buildkite/.go"

RUN <<EOF
	echo "**** Install Essential Packages ****"
	apk add --no-cache \
		curl \
		sed \
		tar
EOF

RUN <<EOF
	echo "**** Install Buildkite ****"
    mkdir -p /buildkite/builds /buildkite/hooks /buildkite/plugins
    curl -sSfL -o /usr/local/bin/ssh-env-config.sh "https://raw.githubusercontent.com/buildkite/docker-ssh-env-config/master/ssh-env-config.sh"
    chmod +x /usr/local/bin/ssh-env-config.sh
    curl -sSfL -o buildkite-agent.tar.gz "https://github.com/buildkite/agent/releases/download/v${BUILDKITE_VERSION}/buildkite-agent-linux-${ARCH}-${BUILDKITE_VERSION}.tar.gz"
    tar xf buildkite-agent.tar.gz
    sed -i 's/token=/#token=/g' buildkite-agent.cfg
    sed -i 's/\$HOME\/.buildkite-agent/\/buildkite/g' buildkite-agent.cfg
    mv buildkite-agent.cfg /buildkite/buildkite-agent.cfg
	mv buildkite-agent /usr/local/bin/buildkite-agent
EOF

RUN <<EOF
	echo "**** Install Authelia CI pre-requisites ****"
    echo "@edge http://dl-cdn.alpinelinux.org/alpine/edge/community" >> /etc/apk/repositories
    echo "@edget http://dl-cdn.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories
	apk add --no-cache \
		apt \
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
		go@edge \
		hub@edget \
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
EOF

RUN <<EOF
	cd /tmp
	echo "**** Add Python Packages ****"
	pip install yamale --break-system-packages
	echo "**** Add pnpm ****"
	npm add --global pnpm@${PNPM_VERSION}
	echo "**** Add s6 overlay ****"
	curl -sSfL -o s6-overlay-noarch.tar.xz "https://github.com/just-containers/s6-overlay/releases/download/v${OVERLAY_VERSION}/s6-overlay-noarch.tar.xz"
	curl -sSfL -o s6-overlay.tar.xz "https://github.com/just-containers/s6-overlay/releases/download/v${OVERLAY_VERSION}/s6-overlay-${ARCH_ALT}.tar.xz"
	tar -C / -Jpxf s6-overlay-noarch.tar.xz
	tar -C / -Jpxf s6-overlay.tar.xz
	echo "**** Add k8s/helm tools ****"
	curl -SsLf -o ct.tar.gz "https://github.com/helm/chart-testing/releases/download/v${CT_VERSION}/chart-testing_${CT_VERSION}_linux_${ARCH}.tar.gz"
	curl -SsLf -o cr.tar.gz "https://github.com/authelia/chart-releaser/archive/refs/tags/v${CR_VERSION}.tar.gz"
	curl -sSLf -o helm.tar.gz "https://get.helm.sh/helm-v${HELM_VERSION}-linux-${ARCH}.tar.gz"
	curl -sSLfO "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/${ARCH}/kubectl"
	tar xfz ct.tar.gz -C /tmp
	tar xfz cr.tar.gz -C /tmp
	tar xfz helm.tar.gz -C /tmp
	cd chart-releaser-${CR_VERSION}
	go mod download
	go build -o /tmp/cr ./cr
	cd /tmp
	chmod +x ct cr linux-${ARCH}/helm kubectl
	mv -t /usr/local/bin/ ct cr linux-${ARCH}/helm kubectl
	mkdir -p /etc/ct
	mv -t /etc/ct/ etc/chart_schema.yaml etc/lintconf.yaml
	echo "**** Patch CVE-2019-5021 ****"
	sed -i -e 's/^root::/root:!:/' /etc/shadow
	echo "**** Create buildkite user and make our folders ****"
	useradd -u 911 -U -d /buildkite -s /bin/false buildkite
	usermod -aG docker,wheel buildkite
	sed -i 's/# %wheel/%wheel/g' /etc/sudoers
	echo "**** Add buildx ****"
	mkdir -p /buildkite/.docker/cli-plugins
	curl -sSfL -o /buildkite/.docker/cli-plugins/docker-buildx "https://github.com/docker/buildx/releases/download/v${BUILDX_VERSION}/buildx-v${BUILDX_VERSION}.linux-amd64"
	chmod +x /buildkite/.docker/cli-plugins/docker-buildx
	docker buildx install
	echo "**** Install Linting tools ****"
	curl -sSfL "https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh" | sh -s -- -b /bin v${GOLANGCILINT_VERSION}
	curl -sSfL "https://raw.githubusercontent.com/reviewdog/reviewdog/master/install.sh" | sh -s -- -b /bin v${REVIEWDOG_VERSION}
	npm add --global markdownlint-cli
	echo "**** Install Coverage tools ****"
	curl -sSfL -o /usr/local/bin/codecov "https://uploader.codecov.io/latest/alpine/codecov"
	chmod +x /usr/local/bin/codecov
	npm add --global nyc
	echo "**** Install Release tools ****"
	npm add --global conventional-changelog-cli
	curl -sSfL -o goreleaser.apk https://github.com/goreleaser/goreleaser/releases/download/v${GORELEASER_VERSION}/goreleaser_${GORELEASER_VERSION}_x86_64.apk
	apk add --allow-untrusted goreleaser.apk
	curl -sSfL https://get.anchore.io/grype | sh -s -- -b /usr/local/bin v${GRYPE_VERSION}
	curl -sSfL https://get.anchore.io/syft | sh -s -- -b /usr/local/bin v${SYFT_VERSION}
	echo "**** Cleanup ****"
	find /usr/local/bin/ -not -user root -exec chown root:root {} +
	rm -rf /tmp/* /buildkite/.pnpm-store
EOF

COPY --link root/ /

VOLUME /buildkite
ENTRYPOINT ["/init"]
