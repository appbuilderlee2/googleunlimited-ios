import Foundation

/// The official API is the only working upload provider at present.
/// A gotohp upload provider must not be activated until the actual Go
/// backend has compiled for iOS, has a reviewed auth bridge, and has
/// passed end-to-end tests with non-sensitive sample media.
enum UploadEngine: String, CaseIterable {
    case official = "Google Photos 官方 API"
    case gotohpExperimental = "gotohp Pixel 實驗模式（尚未可用）"

    var isAvailable: Bool {
        switch self {
        case .official: return true
        case .gotohpExperimental: return false
        }
    }
}

enum GotohpIntegrationError: LocalizedError {
    case coreNotIntegrated
    var errorDescription: String? {
        "gotohp iOS 核心尚未完成跨平台編譯、登入及端到端驗證。此模式不可上傳。"
    }
}

/// Explicit fail-closed adapter; never route a Pixel request through the
/// official quota-counted uploader and never mark it as successful.
struct GotohpUploadAdapter {
    func upload(file: URL) async throws -> String {
        throw GotohpIntegrationError.coreNotIntegrated
    }
}
