package main

import (
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"text/template"
	"time"
)

func main() {
	current, err := readCurrentVersions("./Dockerfile")
	if err != nil {
		panic(err)
	}

	var changes []string

	latest := map[string]string{}

	raw, err := os.ReadFile("./updater/Dockerfile")
	if err != nil {
		panic(err)
	}

	tpml, err := template.New(filepath.Base("./updater/Dockerfile")).
		Option("missingkey=error").
		Parse(string(raw))
	if err != nil {
		panic(err)
	}

	client := &http.Client{Timeout: 10 * time.Second}

	for repo, name := range versionListGitHub {
		version, err := getGitHubLatestReleaseTag(context.Background(), client, repo)
		if err != nil {
			panic(err)
		}

		c, ok := current[name]
		if ok && c != version {
			changes = append(changes, fmt.Sprintf("%s (v%s)", name, version))
		}
		latest[name] = version
	}

	for packageName, name := range versionListNPM {
		version, err := getNPMLatestVersion(context.Background(), client, packageName)
		if err != nil {
			panic(err)
		}

		latest[name] = version
	}

	latest["chart-releaser"] = "1.6.1"

	values := Values{Versions: latest}

	out, err := os.OpenFile("./Dockerfile", os.O_CREATE|os.O_TRUNC|os.O_WRONLY, 0644)
	if err != nil {
		panic(err)
	}
	defer out.Close()

	if err = tpml.Execute(out, values); err != nil {
		panic(err)
	}

	sort.Slice(changes, func(i, j int) bool {
		iIsBK := strings.HasPrefix(changes[i], "buildkite")
		jIsBK := strings.HasPrefix(changes[j], "buildkite")

		if iIsBK != jIsBK {
			return iIsBK
		}

		return changes[i] < changes[j]
	})

	line := fmt.Sprintf("- **%s:** Update %s", time.Now().Format("02/01/2006"), stringJoinWithAnd(changes))

	if err = insertAfterVersion("./README.md", line, "## Version"); err != nil {
		panic(err)
	}
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

var patternVersion = regexp.MustCompile(`^ARG ([A-Z_]+)_VERSION="(\d+\.\d+\.\d+(\.\d+)?)"$`)

func readCurrentVersions(path string) (versions map[string]string, err error) {
	file, err := os.OpenFile(path, os.O_RDONLY, 0644)
	if err != nil {
		return nil, err
	}

	defer file.Close()

	scanner := bufio.NewScanner(file)

	versions = make(map[string]string)

	for scanner.Scan() {
		match := patternVersion.FindStringSubmatch(scanner.Text())

		if len(match) == 4 {
			name := match[1]
			version := match[2]

			switch name {
			case "GOLANGCILINT":
				versions["golangci-lint"] = version
			case "CR":
				versions["chart-releaser"] = version
			case "CT":
				versions["chart-testing"] = version
			case "BUILDKITE":
				versions["buildkite agent"] = version
			default:
				versions[strings.ToLower(name)] = version
			}
		}
	}

	return versions, nil
}

type Values struct {
	Versions map[string]string
}

type latestReleaseResponse struct {
	TagName string `json:"tag_name"`
}

func getGitHubLatestReleaseTag(ctx context.Context, client *http.Client, repo string) (string, error) {
	if repo == "" {
		return "", fmt.Errorf("repo must be provided")
	}

	url := fmt.Sprintf(
		"https://api.github.com/repos/%s/releases/latest",
		repo,
	)

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return "", err
	}

	addUserAgent(req)
	req.Header.Set("Accept", "application/vnd.github+json")
	req.Header.Set("X-GitHub-Api-Version", "2022-11-28")

	if token := os.Getenv("GITHUB_TOKEN"); token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}

	resp, err := client.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("github API error (%s): %s", repo, resp.Status)
	}

	var r latestReleaseResponse
	if err := json.NewDecoder(resp.Body).Decode(&r); err != nil {
		return "", err
	}

	if r.TagName == "" {
		return "", fmt.Errorf("latest release has no tag_name")
	}

	return strings.TrimPrefix(r.TagName, "v"), nil
}

type npmPackageResponse struct {
	DistTags map[string]string `json:"dist-tags"`
}

func getNPMLatestVersion(ctx context.Context, client *http.Client, packageName string) (string, error) {
	if packageName == "" {
		return "", fmt.Errorf("packageName must be provided")
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, "https://registry.npmjs.org/"+url.PathEscape(packageName), nil)
	if err != nil {
		return "", err
	}

	addUserAgent(req)
	req.Header.Set("Accept", "application/json")

	resp, err := client.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("npm registry error: %s", resp.Status)
	}

	var p npmPackageResponse
	if err := json.NewDecoder(resp.Body).Decode(&p); err != nil {
		return "", err
	}

	if p.DistTags == nil {
		return "", fmt.Errorf("missing dist-tags in registry response")
	}

	v := p.DistTags["latest"]
	if v == "" {
		return "", fmt.Errorf("package has no latest dist-tag")
	}

	return strings.TrimPrefix(v, "v"), nil
}

func addUserAgent(req *http.Request) {
	req.Header.Set("User-Agent", "latest-release-tag-go/1.0")
}

func insertAfterVersion(path, newLine, afterLine string) error {
	input, err := os.Open(path)
	if err != nil {
		return err
	}
	defer input.Close()

	var out bytes.Buffer
	scanner := bufio.NewScanner(input)

	inserted := false

	for scanner.Scan() {
		line := scanner.Text()
		out.WriteString(line + "\n")

		if line == afterLine && !inserted {
			out.WriteString(newLine + "\n")
			inserted = true
		}
	}

	if err := scanner.Err(); err != nil {
		return err
	}

	return os.WriteFile(path, out.Bytes(), 0o644)
}

func stringJoinWithAnd(items []string) string {
	switch len(items) {
	case 0:
		return ""
	case 1:
		return items[0]
	case 2:
		return items[0] + " and " + items[1]
	default:
		return strings.Join(items[:len(items)-1], ", ") +
			" and " +
			items[len(items)-1]
	}
}
