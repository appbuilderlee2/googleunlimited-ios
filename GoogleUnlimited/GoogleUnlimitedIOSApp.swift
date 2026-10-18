import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct QueueEntry: Identifiable, Codable {
    let id: UUID
    let filename: String
    let bytes: Int64
    let added: Date
    var status: String = "等待接入上傳服務"
}

@MainActor final class QueueStore: ObservableObject {
    @Published var items: [QueueEntry] = []
    @Published var message: String = "目前只會儲存本地待上傳副本，不會上傳 Google Photos。"
    @Published var isImporting = false
    private let fm = FileManager.default
    private var root: URL {
        let base = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("UploadQueue", isDirectory: true)
    }
    private var index: URL { root.appendingPathComponent("queue.json") }
    init() {
        try? fm.createDirectory(at: root, withIntermediateDirectories: true)
        if let data = try? Data(contentsOf: index),
           let saved = try? JSONDecoder().decode([QueueEntry].self, from: data) {
            items = saved.filter { fm.fileExists(atPath: root.appendingPathComponent($0.filename).path) }
        }
    }
    private func persist() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        try? data.write(to: index, options: .atomic)
    }
    func addFile(at source: URL, preferredName: String? = nil) {
        do {
            let ext = URL(fileURLWithPath: preferredName ?? source.lastPathComponent).pathExtension
            let suffix = ext.isEmpty ? "bin" : ext.lowercased()
            let id = UUID()
            let filename = id.uuidString + "." + suffix
            let dest = root.appendingPathComponent(filename)
            try fm.copyItem(at: source, to: dest)
            let size = (try fm.attributesOfItem(atPath: dest.path)[.size] as? NSNumber)?.int64Value ?? 0
            items.insert(QueueEntry(id: id, filename: filename, bytes: size, added: Date()), at: 0)
            persist()
            message = "已加入本地佇列（尚未上傳）：\(preferredName ?? source.lastPathComponent)"
        } catch {
            message = "匯入失敗：\(error.localizedDescription)"
        }
    }
    func remove(_ item: QueueEntry) {
        try? fm.removeItem(at: root.appendingPathComponent(item.filename))
        items.removeAll { $0.id == item.id }
        persist()
    }
    func clear() {
        items.forEach { try? fm.removeItem(at: root.appendingPathComponent($0.filename)) }
        items.removeAll()
        persist()
        message = "已清除 App 本地待上傳副本，不影響相簿原檔。"
    }
    var totalBytes: Int64 { items.reduce(0) { $0 + $1.bytes } }
}

// PHPicker uses file representations, avoiding loading full-size videos into RAM.
struct MediaPicker: UIViewControllerRepresentable {
    @ObservedObject var store: QueueStore
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.selectionLimit = 0
        config.filter = .any(of: [.images, .videos])
        config.preferredAssetRepresentationMode = .current
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(store: store, dismiss: { dismiss() }) }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let store: QueueStore
        let dismiss: () -> Void
        init(store: QueueStore, dismiss: @escaping () -> Void) {
            self.store = store
            self.dismiss = dismiss
        }
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            dismiss()
            for result in results {
                let provider = result.itemProvider
                let type = provider.registeredTypeIdentifiers.first(where: {
                    UTType($0)?.conforms(to: .movie) == true ||
                    UTType($0)?.conforms(to: .image) == true
                }) ?? (provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier)
                    ? UTType.movie.identifier : UTType.image.identifier)
                let name = provider.suggestedName ?? (UTType(type)?.preferredFilenameExtension.map { "media." + $0 } ?? "media.bin")
                // Copy inside the callback: the provider's temporary URL does not survive it.
                provider.loadFileRepresentation(forTypeIdentifier: type) { url, error in
                    guard let url else {
                        Task { @MainActor in self.store.message = "選取失敗：\(error?.localizedDescription ?? "檔案不可讀")" }
                        return
                    }
                    let staging = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + "." + (url.pathExtension.isEmpty ? "bin" : url.pathExtension))
                    do {
                        try FileManager.default.copyItem(at: url, to: staging)
                        Task { @MainActor in
                            self.store.addFile(at: staging, preferredName: name)
                            try? FileManager.default.removeItem(at: staging)
                        }
                    } catch {
                        Task { @MainActor in self.store.message = "暫存失敗：\(error.localizedDescription)" }
                    }
                }
            }
        }
    }
}

struct ContentView: View {
    @StateObject private var store = QueueStore()
    @State private var showPicker = false
    @State private var showFiles = false
    @State private var confirmClear = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("本地待上傳", systemImage: "tray.full.fill").font(.headline)
                        HStack {
                            VStack(alignment: .leading) {
                                Text("\(store.items.count)").font(.system(size: 38, weight: .bold, design: .rounded))
                                Text("個檔案").foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text(ByteCountFormatter.string(fromByteCount: store.totalBytes, countStyle: .file))
                                    .font(.title3.bold())
                                Text("儲存於此 iPhone").foregroundStyle(.secondary)
                            }
                        }
                    }.padding().background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
                    Label("未連接 Google Photos。所有檔案只係 App 內嘅本地副本，並未備份到雲端。", systemImage: "exclamationmark.shield.fill")
                        .font(.subheadline).foregroundStyle(.orange)
                    HStack {
                        Button { showPicker = true } label: {
                            Label("從相簿選擇", systemImage: "photo.on.rectangle.angled")
                        }.buttonStyle(.borderedProminent)
                        Button { showFiles = true } label: {
                            Label("從檔案加入", systemImage: "folder")
                        }.buttonStyle(.bordered)
                    }
                    Text(store.message).font(.caption).foregroundStyle(.secondary)
                    HStack {
                        Text("本地佇列").font(.headline)
                        Spacer()
                        if !store.items.isEmpty {
                            Button("清空", role: .destructive) { confirmClear = true }
                        }
                    }
                    if store.items.isEmpty {
                        ContentUnavailableView("未選擇相片", systemImage: "photo.stack",
                          description: Text("從相簿或檔案加入相片／影片。"))
                    } else {
                        LazyVStack(spacing: 8) {
                            ForEach(store.items) { item in
                                HStack(spacing: 12) {
                                    Image(systemName: "doc.richtext").foregroundStyle(.secondary)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(item.filename).font(.subheadline).lineLimit(1)
                                        Text(ByteCountFormatter.string(fromByteCount: item.bytes, countStyle: .file)
                                            + " · " + item.status)
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Button(role: .destructive) { store.remove(item) } label: {
                                        Image(systemName: "trash")
                                    }.buttonStyle(.borderless)
                                }.padding(12).background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
                            }
                        }
                    }
                    Link(destination: URL(string: "https://photos.google.com/")!) {
                        Label("開啟 Google Photos（自行確認備份）", systemImage: "arrow.up.right.square")
                    }.font(.subheadline)
                }.padding()
            }
            .navigationTitle("GoogleUnlimited")
            .sheet(isPresented: $showPicker) { MediaPicker(store: store) }
            .fileImporter(isPresented: $showFiles, allowedContentTypes: [.image, .movie, .video, .audiovisualContent],
                          allowsMultipleSelection: true) { result in
                switch result {
                case .success(let urls):
                    for url in urls {
                        let access = url.startAccessingSecurityScopedResource()
                        store.addFile(at: url)
                        if access { url.stopAccessingSecurityScopedResource() }
                    }
                case .failure(let error): store.message = "檔案選取失敗：\(error.localizedDescription)"
                }
            }
            .confirmationDialog("只清除 App 內待上傳副本？", isPresented: $confirmClear) {
                Button("清除本地副本", role: .destructive) { store.clear() }
            } message: {
                Text("呢啲檔案尚未上傳 Google Photos。唔會影響 iPhone 相簿原檔。")
            }
        }
    }
}
@main struct GoogleUnlimitedIOSApp: App {
    var body: some Scene { WindowGroup { ContentView() } }
}
