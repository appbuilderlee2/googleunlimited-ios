import SwiftUI
import GotohpCore

/// Validates the actual GoMobile symbol is callable by Swift in the packaged IPA.
/// It does not send credentials, authenticate, or initiate network uploads.
struct GotohpCoreStatusView: View {
    @State private var result: String = "未檢查"
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Label("gotohp iOS 核心", systemImage: "cpu")
                .font(.headline)
            Text(result).font(.caption).textSelection(.enabled)
            Button("檢查核心連接") {
                result = IosbridgeHealthcheck()
            }.buttonStyle(.bordered)
            Text("核心檢查只證明 Swift 可以呼叫 Go。手動 oauth_token 尚未轉換為 gotohp 認證，上傳功能仍鎖定。")
                .font(.caption).foregroundStyle(.orange)
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}
