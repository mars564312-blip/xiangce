import Foundation

/// 感知哈希缓存（对应 Android 版 ImageHashCache）
///
/// 用 JSON 文件持久化到 Application Support，键为 assetIdentifier。
/// 线程安全：所有读写走串行队列。
final class ImageHashCache {
    static let shared = ImageHashCache()

    private let fileURL: URL
    private let queue = DispatchQueue(label: "com.tabula.v3.hashcache", qos: .utility)
    private var cache: [String: Int64] = [:]

    init(fileURL: URL? = nil) {
        let defaultURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("TabulaV3", isDirectory: true)
            .appendingPathComponent("image_hashes.json")
        self.fileURL = fileURL ?? defaultURL
        load()
    }

    private func load() {
        queue.sync {
            guard FileManager.default.fileExists(atPath: fileURL.path),
                  let data = try? Data(contentsOf: fileURL),
                  let decoded = try? JSONDecoder().decode([String: Int64].self, from: data) else { return }
            cache = decoded
        }
    }

    func hash(for id: String) -> Int64? {
        queue.sync { cache[id] }
    }

    func hashes(for ids: [String]) -> [String: Int64] {
        queue.sync { ids.reduce(into: [:]) { result, id in if let h = cache[id] { result[id] = h } } }
    }

    func save(_ hash: Int64, for id: String) {
        saveHashes([id: hash])
    }

    func saveHashes(_ newHashes: [String: Int64]) {
        queue.sync {
            cache.merge(newHashes) { _, new in new }
            persist()
        }
    }

    func removeAll() {
        queue.sync {
            cache.removeAll()
            persist()
        }
    }

    private func persist() {
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(cache)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("[ImageHashCache] persist failed: \(error)")
        }
    }
}
