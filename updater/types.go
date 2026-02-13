package main

type Values struct {
	Versions map[string]string
}

type latestReleaseResponse struct {
	TagName string `json:"tag_name"`
}
