package main

import "regexp"

var patternVersion = regexp.MustCompile(`^ARG ([A-Z_]+)_VERSION="(\d+\.\d+\.\d+(\.\d+)?)"$`)

var currentVersionMap = map[string]string{
	"GOLANGCILINT": "golangci-lint",
	"CR":           "chart-releaser",
	"CT":           "chart-testing",
	"BUILDKITE":    "buildkite agent",
}

var frozenVersions = []string{
	"chart-releaser",
}

// versionListNPM maps the npm package name (key) to the internal package name (value).
var versionListNPM = map[string]string{
	"pnpm": "pnpm",
}

// versionListGitHub maps the github repo name (key) to the internal package name (value).
var versionListGitHub = map[string]string{
	"anchore/grype":              "grype",
	"anchore/syft":               "syft",
	"buildkite/agent":            "buildkite agent",
	"crate-ci/typos":             "typos",
	"docker/buildx":              "buildx",
	"golangci/golangci-lint":     "golangci-lint",
	"goreleaser/goreleaser":      "goreleaser",
	"helm/chart-releaser":        "chart-releaser",
	"helm/chart-testing":         "chart-testing",
	"helm/helm":                  "helm",
	"just-containers/s6-overlay": "overlay",
	"koalaman/shellcheck":        "shellcheck",
	"kubernetes/kubernetes":      "kubectl",
	"reviewdog/reviewdog":        "reviewdog",
}
