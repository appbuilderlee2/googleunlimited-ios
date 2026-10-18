# GoogleUnlimited iOS

## 真正 gotohp 上傳入口（實驗性，未連 Swift）

`bridge/real_core_bridge.go` 現已呼叫上游實際 `core.NewApi` 及 `core.UploadFile`，處理真實媒體上傳路徑。接口 `UploadWithCredential(filePath, credential)` **只接受完整 gotohp Android 認證 query string**，不是之前手動輸入的 `oauth_token` Cookie。橋接目前會為每次調用建立私有暫存設定並清理，禁用 DeleteFromHost；仍未進行 iPhone 端、認證安全及網絡測試。

**安全隔離：** 主 SwiftUI App 未調用此方法；不會擅自使用 Keychain 的 oauth_token。GoMobile XCFramework 是否可因新接口重新編譯仍須最新 GitHub Action 成功驗證。未有真實媒體上傳成功證據，亦無免費無限容量保證。

## 真實 gotohp Go 核心橋接（新）

已加入 [Build Gotohp Core XCFramework](.github/workflows/build-gotohp-core.yml)。此 Workflow 固定 `xob0t/gotohp` Commit `97a5dc02db81f5571ce6b586f478600fcd44dd89`，使用真正 `app/core` 套件建立 GoMobile XCFramework。首個暴露接口 `Healthcheck()` 會使用上游 `core.UploadOptions`；**不是上傳 API**，不使用 Token、亦不連線 Google。

目前尚未運行／確認 XCFramework 編譯成功，也未將其鏈接到主 IPA。下一步需要 Build 成功後檢查產物、再加入 Swift 端呼叫、逐步整合媒體及安全認證。請勿因為 CI 成功便聲稱 Pixel 無限容量或可上傳。


## 真正 gotohp 核心移植進度

已加入 [gotohp iOS 相容性審查 Workflow](.github/workflows/audit-gotohp-ios.yml)，使用 upstream `xob0t/gotohp` **真實 backend**（唔係示範 Go 函式）執行 iOS arm64 編譯檢查，並輸出依賴圖及完整編譯日誌。Actions 尚待運行驗證。Workflow 會記錄當次上游 Commit；正式移植前必須再固定已審核 Commit，避免上游更新引入不明程式碼。

新增 [GotohpUploadAdapter.swift](GoogleUnlimited/GotohpUploadAdapter.swift) 以 **fail closed** 形式保護 iOS App：gotohp 未真正移植同驗證之前，所有實驗 Pixel 上傳請求都明確失敗，絕對唔會冒充官方 API 上傳成功，亦唔會傳遞 Keychain Token。

**尚未完成：** 拆分 desktop-only 依賴、GoMobile binding、Swift ↔ Go 認證橋接、gotohp 真實上傳及 iPhone 實機測試。唔可以聲稱已經有 Pixel 無限容量。


## Pixel 實驗模式：手動 Token（未接入上傳核心）

iPhone App 現在提供 SecureField，可手動貼入測試帳戶的 `oauth_token`，使用 iOS Keychain `WhenUnlockedThisDeviceOnly` 儲存，支援本機刪除。此 Token **不會**用於現有 Google Photos 官方 API，也**不會**經 GitHub Actions、日誌或網絡傳送。

**重要：這只完成輸入和儲存介面，不是有效的 gotohp 登入。** gotohp iOS 核心、認證交換、上傳及免費容量均未實作／驗證。切勿以為顯示「已儲存」即代表已登入。請只用不重要的專用測試帳戶，並了解 Cookie 憑證外洩的風險。

## Google Photos 官方上傳（開發中）

iOS 版已接入 Google Sign-In 及 Google Photos Library API 的兩步上傳流程：
1. 由 iPhone 選相並複製到 App 本地佇列。
2. 使用 Google OAuth `photoslibrary.appendonly` 登入。
3. 按「開始上傳」；先 POST `/v1/uploads`，再 POST `/v1/mediaItems:batchCreate`。
4. 只在建立媒體項目成功時紀錄 Google media ID。失敗檔案保留作重試。

**這是官方 API：全部上傳以原畫質計入 Google 帳戶容量，並非 Pixel 模擬無限備份。** API 只可管理 App 建立的媒體。原始檔案不會自動刪除。暫時係前景順序上傳；大型影片背景續傳及更精細進度百分比仍需開發。

### 你必須設定 Google Cloud（一次性）

1. 在 [Google Cloud Console](https://console.cloud.google.com/) 建立／選擇專案，啟用 **Photos Library API**。
2. 配置 **OAuth consent screen**，要求 `https://www.googleapis.com/auth/photoslibrary.appendonly`；處於 Testing 時將自己的 Google 帳戶加到 Test users。
3. 建立 OAuth **iOS application** client，Bundle ID 設為 `com.appbuilderlee2.googleunlimitedios`。
4. 將該 iOS **Client ID** 放到 GitHub Repo **Settings → Secrets and variables → Actions → Variables → New repository variable**：
   - Name: `GOOGLE_IOS_CLIENT_ID`
   - Value: 例如 `123456789-abcdef.apps.googleusercontent.com`（純 Client ID，唔係 Client Secret，更唔係 Google Token）。
5. 重新運行 **Build iOS IPA**，下載新 artifact，再用 AltStore 安裝。未設定 Client ID 時 App 可啟動，但會顯示 OAuth 未設定，唔會嘗試上傳。

不可將 Google 密碼、OAuth Cookie、Refresh Token、Apple ID 密碼或私人照片交到 GitHub Actions。GitHub Actions 使用公開性質的 OAuth Client ID，登入 Token 由 iOS Google Sign-In SDK 管理。

### 尚未實機確認

已提交原始碼與 workflow，**但仍未驗證新版本 GitHub Actions build／Google Cloud 登入／真實照片上傳**。首次測試用獨立測試帳戶及 1–2 張非重要照片；核對 Google Photos 及容量後再處理大批檔案。

---


Native SwiftUI iPhone app prototype for selecting photos/videos and preparing a **local queue**.

**Important:** The new official API integration requires your own Google Cloud OAuth configuration. It does **not** emulate a Pixel or provide unlimited storage. Do not delete originals based only on an in-app success message.

## Features
- Traditional Chinese SwiftUI dashboard
- Select multiple photos/videos from Photos using Apple's PHPicker (limited photo access)
- Import file copies using Files
- Copy selected media into the app sandbox (Documents/UploadQueue) before displaying them as queued
- Persist queue state as JSON in Documents
- Inspect selected filenames, sizes, statuses and remove app-local copies
- Buttons to open Google Photos and clear local queue with confirmation
- Official Google OAuth + Google Photos upload, once configured; background upload not implemented

## Build on GitHub
Actions → **Build iOS IPA** → Run workflow. Download the `googleunlimited-ios-unsigned-ipa` artifact. The IPA is **unsigned**, intended to be signed by AltStore Classic on device, subject to AltStore's current capabilities, Apple ID/device limits, and iOS compatibility. GitHub Actions must not contain Apple credentials.

For local development, run `brew install xcodegen && xcodegen generate`, then open the generated `GoogleUnlimited.xcodeproj` using a recent compatible Xcode.

## Next phase
Improve large-file resumable transfer, persistent background uploads and byte-level progress. Pixel spoofing is not included and is not guaranteed to work on iOS.

## Safety
Never submit OAuth cookies, Google tokens, Apple ID passwords, signing keys or user photographs to issues or Actions. The app stores local file copies until you remove them. Remove only copies inside the app, not your original Photos media.
