import Foundation
import UniformTypeIdentifiers

// Google Photos Library API two-step upload. A file is successful ONLY after
// mediaItems.batchCreate returns a successful newMediaItemResult.
struct PhotosUploader {
    private let api = "https://photoslibrary.googleapis.com/v1"
    func upload(file: URL, originalName: String, accessToken: String) async throws -> String {
        guard FileManager.default.fileExists(atPath: file.path) else { throw UploadError.missingFile }
        let fileSize = ((try? FileManager.default.attributesOfItem(atPath: file.path)[.size]) as? NSNumber)?.int64Value ?? 0
        let extensionType = UTType(filenameExtension: file.pathExtension)
        let mime = extensionType?.preferredMIMEType ?? "application/octet-stream"
        let isVideo = extensionType?.conforms(to: .movie) == true || mime.hasPrefix("video/")
        if fileSize > (isVideo ? 20_000_000_000 : 200_000_000) {
            throw UploadError.badResponse("檔案超過官方 API 大小限制")
        }
        var first = URLRequest(url: URL(string: api + "/uploads")!)
        first.httpMethod = "POST"
        first.setValue("Bearer " + accessToken, forHTTPHeaderField: "Authorization")
        first.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        first.setValue(mime, forHTTPHeaderField: "X-Goog-Upload-Content-Type")
        first.setValue("raw", forHTTPHeaderField: "X-Goog-Upload-Protocol")
        // URLSession.upload(fromFile:) avoids loading entire videos into memory.
        let (bytes, response) = try await URLSession.shared.upload(for: first, fromFile: file)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
              let uploadToken = String(data: bytes, encoding: .utf8),
              !uploadToken.isEmpty else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw UploadError.badResponse("上傳檔案失敗 HTTP \(status)")
        }
        var second = URLRequest(url: URL(string: api + "/mediaItems:batchCreate")!)
        second.httpMethod = "POST"
        second.setValue("Bearer " + accessToken, forHTTPHeaderField: "Authorization")
        second.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["newMediaItems": [
            ["simpleMediaItem": ["uploadToken": uploadToken, "fileName": originalName]]
        ]]
        second.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, createResponse) = try await URLSession.shared.data(for: second)
        let status = (createResponse as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = (json["newMediaItemResults"] as? [[String: Any]])?.first,
              let itemStatus = result["status"] as? [String: Any],
              (itemStatus["code"] as? Int ?? 0) == 0,
              let media = result["mediaItem"] as? [String: Any],
              let mediaID = media["id"] as? String else {
            throw UploadError.badResponse("建立媒體項目失敗 HTTP \(status)，未確認成功")
        }
        return mediaID
    }
}
