# GoMobile iOS bridge — first milestone

This is an isolated **build experiment**, not a gotohp port.

## Check on GitHub

Open **Actions → Build Go iOS Bridge (experiment)**, choose **Run workflow**. The build attempts `gomobile bind` on a minimal, network-free Go package and publishes an `xcframework` artifact if successful.

It intentionally provides only `Version` and `Healthcheck`, without credentials, Google networking, spoofed device profiles, photo access, or upload behavior. The main unsigned iOS IPA is unchanged; do not assume it includes this framework.

## Acceptance criteria

- GitHub Actions job finishes successfully and the XCFramework has a device arm64 slice.
- Later: add an Xcode target dependency and prove Swift can call `Healthcheck` in the iOS build.
- Later: audit an exact gotohp upstream revision and separate its portable logic from desktop/UI and credentials.
- Never print, transmit or submit `oauth_token` to CI.
- Never claim that device emulation guarantees unlimited storage.

GoMobile requires a macOS system with Xcode installed. See [golang/mobile](https://github.com/golang/mobile).
