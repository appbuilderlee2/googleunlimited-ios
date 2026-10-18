// Package bridge is a safe GoMobile integration smoke test.
// No authentication, network activity, device spoofing or uploads are performed.
package bridge

func Version() string { return "bridge-smoke-0.1" }
func Healthcheck() string { return "Go → iOS bridge ready (no uploads)" }
