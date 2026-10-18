# Pixel-mode iOS feasibility (research only)

**Status: NOT IMPLEMENTED OR VERIFIED.** The current standalone SwiftUI app implements only the official Google Photos upload API, which **uses account quota**. Do not advertise "unlimited" as a functional feature until verified on an eligible account/device and service side.

## Existing iOS port found

- [tqmane/gunshot](https://github.com/tqmane/gunshot) is an independent experimental iOS port of the [xob0t/gotohp](https://github.com/xob0t/gotohp) Go core.
- It describes a Pixel XL / original-quality profile, but explicitly states profile selection does not guarantee quota treatment.
- The jailed/sideload route **injects a dylib into the Google Photos app**, or uses LiveContainer; it is **not** an ordinary standalone SwiftUI IPA and is not plug-compatible with this app.
- It reports some sign-in interference when injected and says foreground uploading is necessary for jailed mode.
- Such injection needs significant code-security and account-security review before use; do not copy auth tokens/cookies or Google Photos private application data into this repository or CI.

## Options

1. Keep current official API uploader as the stable supported path (quota-counted).
2. Independently audit source and dependencies of Gunshot, including its build outputs, authentication access, app injection, and license; test with an isolated account and noncritical images. Do not distribute modified Google Photos or private signing credentials from CI.
3. Research a **standalone** Go-to-iOS library bridge instead of injection. Its authentication requirements and iOS SDK/background compatibility are currently unsolved. Never call a demo "unlimited" merely because it transfers files.

## Acceptance criteria before any implementation claim

- Reproducible build from reviewed/pinned upstream commit
- iOS sandbox and signing compatibility confirmed
- Clear, revocable user consent for any credential handling; no secret values in logs/CI
- Media present, independently downloadable in Google Photos
- Google Photos item details and account storage usage checked with nonimportant test media
- No automatic removal of the only local originals
- Honest status: attempted Pixel device profile is not Google's guarantee of free storage

See upstream projects for current compatibility and known limitations.
