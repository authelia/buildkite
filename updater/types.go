package main

import (
	"context"
	"net/http"
)

type Values struct {
	Versions map[string]string
}

type latestReleaseResponse struct {
	TagName string `json:"tag_name"`
}

type versionChecker func(ctx context.Context, client *http.Client, repo string) (version string, err error)
