import Foundation

/// 相册元数据（对应 Android AlbumManager.AlbumMetadata）
/// 只存颜色/排序/隐藏等自定义信息，照片归属的真相来源是 Photos 框架
struct AlbumMetadata: Codable {
    var id: String?
    var name: String
    var color: Int64?
    var textColor: Int64?
    var order: Int
    var createdAt: Int64
    var isHidden: Bool
    var isExcludedFromRecommend: Bool

    init(
        name: String,
        id: String? = nil,
        color: Int64? = nil,
        textColor: Int64? = nil,
        order: Int = 0,
        createdAt: Int64 = Date().milliseconds,
        isHidden: Bool = false,
        isExcludedFromRecommend: Bool = false
    ) {
        self.name = name
        self.id = id
        self.color = color
        self.textColor = textColor
        self.order = order
        self.createdAt = createdAt
        self.isHidden = isHidden
        self.isExcludedFromRecommend = isExcludedFromRecommend
    }
}

/// 元数据持久化：App 沙盒 Application Support 下的 JSON 文件
/// 对应 Android context.filesDir/albums_metadata.json
final class AlbumMetadataStore {
    static let shared = AlbumMetadataStore()

    private let fileURL: URL

    init(fileURL: URL? = nil) {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("TabulaV3", isDirectory: true)
        self.fileURL = fileURL ?? support.appendingPathComponent("albums_metadata.json")
    }

    func allMetadata() -> [String: AlbumMetadata] {
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let list = try? JSONDecoder().decode([AlbumMetadata].self, from: data) else { return [:] }
        return Dictionary(uniqueKeysWithValues: list.map { ($0.name, $0) })
    }

    func save(_ metadata: AlbumMetadata) {
        var all = allMetadata()
        all[metadata.name] = metadata
        persist(Array(all.values))
    }

    func remove(name: String) {
        var all = allMetadata()
        all.removeValue(forKey: name)
        persist(Array(all.values))
    }

    private func persist(_ list: [AlbumMetadata]) {
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(list)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("[AlbumMetadataStore] persist failed: \(error)")
        }
    }
}
