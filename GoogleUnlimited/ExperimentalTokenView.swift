import SwiftUI
import Security

/// Experimental gotohp token storage. No network calls and no Pixel emulation.
@MainActor final class ExperimentalTokenStore: ObservableObject {
    @Published private(set) var hasToken = false
    @Published var status = "尚未設定實驗模式 Token"
    private let service = "com.appbuilderlee2.googleunlimitedios.gotohp"
    private let account = "experimental-oauth-token"

    init() { hasToken = (read() != nil) }

    private func query() -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }
    private func read() -> Data? {
        var q = query()
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        return SecItemCopyMatching(q as CFDictionary, &result) == errSecSuccess ? result as? Data : nil
    }
    func save(_ token: String) -> Bool {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 8192 else {
            status = "Token 不可留空，亦不可超過 8192 字元"
            return false
        }
        let value = Data(trimmed.utf8)
        var add = query()
        add[kSecValueData as String] = value
        add[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let existing = SecItemCopyMatching(query() as CFDictionary, nil)
        let result: OSStatus
        if existing == errSecSuccess {
            result = SecItemUpdate(query() as CFDictionary,
                    [kSecValueData as String: value] as CFDictionary)
        } else {
            result = SecItemAdd(add as CFDictionary, nil)
        }
        hasToken = result == errSecSuccess
        status = hasToken ? "Token 已加密儲存喺此 iPhone Keychain，尚未驗證登入。" : "Keychain 儲存失敗（代碼 \(result)）"
        return hasToken
    }
    func delete() {
        let result = SecItemDelete(query() as CFDictionary)
        hasToken = false
        status = (result == errSecSuccess || result == errSecItemNotFound) ?
            "已清除本機 Token" : "刪除失敗（代碼 \(result)）"
    }
}

struct ExperimentalTokenView: View {
    @StateObject private var storage = ExperimentalTokenStore()
    @State private var input = ""
    @State private var confirmDelete = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Pixel 實驗模式 — 手動 Token", systemImage: "lock.shield")
                .font(.headline)
            Text("與 Mac 版相同，預留手動輸入 oauth_token 嘅方式。只會儲存在本機 Keychain，唔會上傳到 GitHub 或任何伺服器。")
                .font(.caption).foregroundStyle(.secondary)
            SecureField("貼上測試帳戶 oauth_token", text: $input)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textContentType(.password)
            HStack {
                Button("儲存 Token") {
                    if storage.save(input) { input = "" }
                }.buttonStyle(.borderedProminent)
                Button("刪除 Token", role: .destructive) { confirmDelete = true }
                    .disabled(!storage.hasToken)
            }
            Text(storage.status).font(.caption).foregroundStyle(.secondary)
            Text("尚未接入 gotohp iOS 引擎；儲存 Token 並不代表已登入、已上傳或享有免費無限容量。請勿使用主要 Google 帳戶。")
                .font(.caption).foregroundStyle(.orange)
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .confirmationDialog("刪除本機認證資料？", isPresented: $confirmDelete) {
            Button("刪除", role: .destructive) { storage.delete() }
        }
    }
}
