// Package bridge exposes the real gotohp upload engine to GoMobile.
// Important: expects a gotohp COMPLETE auth string, NOT an oauth_token cookie.
// No Swift UI or Keychain connectivity until credential exchange is audited.
package bridge

import (
    "app/core"
    "context"
    "errors"
    "fmt"
    "os"
    "path/filepath"
    "net/url"
    "strings"
)

func Version() string { return "gotohp-core-bridge-0.2" }

func Healthcheck() string {
    return "gotohp core linked; upload method available; credential exchange not integrated"
}

// UploadWithCredential invokes the actual upstream core.UploadFile method.
// The credential must be a valid complete gotohp auth query string and must
// never be placed in logs, GitHub, command-line arguments or error reporting.
// Uses an isolated temporary config, removed when the call finishes.
// Serial execution only: upstream config is process-global.
func UploadWithCredential(filePath string, credential string) (string, error) {
    credential = strings.TrimSpace(credential)
    if !core.LooksLikeAuthString(credential) {
        return "", errors.New("requires complete gotohp auth string; raw oauth_token cookie unsupported")
    }
    values, err := url.ParseQuery(credential)
    if err != nil { return "", errors.New("invalid credential format") }
    email := values.Get("Email")
    if email == "" { return "", errors.New("missing credential email") }
    info, err := os.Stat(filePath)
    if err != nil || !info.Mode().IsRegular() {
        return "", errors.New("media file not readable")
    }

    dir, err := os.MkdirTemp("", "gotohp-ios-")
    if err != nil { return "", errors.New("cannot create private credential staging directory") }
    defer os.RemoveAll(dir)
    if err = os.Chmod(dir, 0700); err != nil { return "", errors.New("cannot restrict staging permissions") }
    configFile := filepath.Join(dir, "gotohp.config")
    if err = core.LoadConfig(configFile); err != nil {
        return "", errors.New("cannot initialize gotohp credential store")
    }
    config := &core.ConfigManager{}
    if err = config.AddCredentials(credential); err != nil {
        return "", errors.New("gotohp credential validation failed")
    }
    api, err := core.NewApi(core.ApiOptions{Account: email})
    if err != nil { return "", errors.New("cannot initialize gotohp client") }
    options := core.UploadOptions{
        Api: core.ApiOptions{Account: email},
        Threads: 1, Recursive: false, DeleteFromHost: false,
        ForceUpload: false, PairLivePhotos: false,
    }
    mediaKey, err := core.UploadFile(context.Background(), api, filePath, options, 0, core.NopReporter{})
    if err != nil { return "", fmt.Errorf("gotohp upload failed: %w", err) }
    if mediaKey == "" { return "", errors.New("no returned media key; cannot confirm upload") }
    return mediaKey, nil
}
