import Foundation
import UIKit
import GoogleSignIn

@MainActor final class GoogleSession: ObservableObject {
    @Published var email: String?
    @Published var errorMessage: String?
    static let scope = "https://www.googleapis.com/auth/photoslibrary.appendonly"
    var configured: Bool {
        guard let client = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String else { return false }
        return client.hasSuffix(".apps.googleusercontent.com") && !client.hasPrefix("CONFIGURE_")
    }
    init() {
        guard configured else { return }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as! String)
        GIDSignIn.sharedInstance.restorePreviousSignIn { user, _ in
            DispatchQueue.main.async { self.email = user?.profile?.email }
        }
    }
    func signIn() async {
        guard configured else { errorMessage = "請先喺 GitHub Actions 設定 GOOGLE_IOS_CLIENT_ID。"; return }
        guard let controller = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).first(where: { $0.activationState == .foregroundActive })?
            .windows.first(where: { $0.isKeyWindow })?.rootViewController else {
            errorMessage = "無法開啟登入畫面。"; return
        }
        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: controller,
                                                                  hint: nil,
                                                                  additionalScopes: [Self.scope])
            email = result.user.profile?.email
            errorMessage = nil
        } catch {
            errorMessage = "登入失敗：\(error.localizedDescription)"
        }
    }
    func token() async throws -> String {
        guard let user = GIDSignIn.sharedInstance.currentUser else { throw UploadError.notSignedIn }
        let refreshed = try await user.refreshTokensIfNeeded()
        guard refreshed.grantedScopes?.contains(Self.scope) == true else { throw UploadError.missingScope }
        return refreshed.accessToken.tokenString
    }
    func signOut() {
        GIDSignIn.sharedInstance.signOut()
        email = nil
    }
}

enum UploadError: LocalizedError {
    case notSignedIn, missingScope, badResponse(String), missingFile
    var errorDescription: String? {
        switch self {
        case .notSignedIn: return "請先登入 Google 帳戶"
        case .missingScope: return "未取得 Google Photos 上傳權限，請重新登入"
        case .badResponse(let message): return "Google Photos 回應錯誤：\(message)"
        case .missingFile: return "本地待上傳檔案不存在"
        }
    }
}
