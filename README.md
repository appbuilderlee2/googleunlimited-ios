# GoogleUnlimited iOS

Native SwiftUI iPhone app prototype for selecting photos/videos and preparing a **local queue**.

**Important:** Version 0.1.0 does **not** upload anything to Google Photos. It does **not** emulate a Pixel, provide unlimited storage, or handle Google authentication. Do not delete your originals on the assumption that a backup has occurred. No backend and no credentials are required.

## Features
- Traditional Chinese SwiftUI dashboard
- Select multiple photos/videos from Photos using Apple's PHPicker (limited photo access)
- Import file copies using Files
- Copy selected media into the app sandbox (Documents/UploadQueue) before displaying them as queued
- Persist queue state as JSON in Documents
- Inspect selected filenames, sizes, statuses and remove app-local copies
- Buttons to open Google Photos and clear local queue with confirmation
- No background upload or misleading "success" state

## Build on GitHub
Actions → **Build iOS IPA** → Run workflow. Download the `googleunlimited-ios-unsigned-ipa` artifact. The IPA is **unsigned**, intended to be signed by AltStore Classic on device, subject to AltStore's current capabilities, Apple ID/device limits, and iOS compatibility. GitHub Actions must not contain Apple credentials.

For local development, open `GoogleUnlimited.xcodeproj` using a recent compatible Xcode.

## Next phase
Implement an optional **official Google Photos API** uploader with user-authorized OAuth and meaningful per-file verification. Official API uploads consume account quota. Pixel spoofing is not included and is not guaranteed to work on iOS.

## Safety
Never submit OAuth cookies, Google tokens, Apple ID passwords, signing keys or user photographs to issues or Actions. The app stores local file copies until you remove them. Remove only copies inside the app, not your original Photos media.
