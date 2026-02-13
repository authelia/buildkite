package main

import "regexp"

var patternVersion = regexp.MustCompile(`^ARG ([A-Z_]+)_VERSION="(\d+\.\d+\.\d+(\.\d+)?)"$`)

var frozenVersions = []string{
	"chart-releaser",
}

// versionListNPM maps the npm package name (key) to the internal package name (value).
var versionListNPM = map[string]string{
	"pnpm": "pnpm",
}

// versionListGitHub maps the github repo name (key) to the internal package name (value).
var versionListGitHub = map[string]string{
	"docker/buildx":              "buildx",
	"buildkite/agent":            "buildkite agent",
	"helm/helm":                  "helm",
	"helm/chart-testing":         "chart-testing",
	"helm/chart-releaser":        "chart-releaser",
	"golangci/golangci-lint":     "golangci-lint",
	"reviewdog/reviewdog":        "reviewdog",
	"just-containers/s6-overlay": "overlay",
	"anchore/syft":               "syft",
	"anchore/grype":              "grype",
	"goreleaser/goreleaser":      "goreleaser",
	"kubernetes/kubernetes":      "kubectl",
}
