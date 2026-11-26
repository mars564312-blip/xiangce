import Foundation
import Photos
import SwiftUI

/// 照片整理主视图模型（对应 Android 的 DeckScreen + MainActivity 的状态整合）
@MainActor
final class PhotoLibraryViewModel: ObservableObject {
    @Published private(set) var images: [ImageFile] = []
    @Published private(set) var albums: [Album] = []
    @Published private(set) var similarGroups: [SimilarGroup] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    @Published var sortOrder: SortOrder = .dateModifiedDesc

    private let repository = PhotoLibraryRepository()
    private let albumManager = AlbumManager.shared
    private let permissionManager = PhotoPermissionManager.shared
    private let detector = SimilarGroupDetector()

    // MARK: - 加载

    func load() async {
        guard permissionManager.state.canReadPhotos else {
            errorMessage = "需要照片库权限才能整理照片"
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let loaded = await repository.loadAllImages(sortOrder: sortOrder)
        images = loaded

        await albumManager.loadAlbums()
        albums = albumManager.albums

        // dHash 计算较轻，这里同步补齐缓存；照片量大时可改为后台分批
        let hashes = await ensureHashes(for: loaded)
        similarGroups = detector.detect(images: loaded, hashes: hashes)
    }

    /// 对应 SimilarGroupDetector.ensureHashesComputed
    private func ensureHashes(for images: [ImageFile]) async -> [String: Int64] {
        let cached = ImageHashCache.shared.hashes(for: images.map(\.id))
        let missing = images.filter { cached[$0.id] == nil }
        guard !missing.isEmpty else { return cached }

        var result = cached
        // 分批处理，避免一次性请求过多缩略图
        for batch in missing.chunked(into: 10) {
            let computed = await withTaskGroup(of: (String, Int64?).self) { group in
                for image in batch {
                    group.addTask {
                        let hash = await PerceptualHash.computeDHash(
                            assetIdentifier: image.assetIdentifier,
                            repository: self.repository
                        )
                        return (image.id, hash)
                    }
                }
                var acc: [String: Int64] = [:]
                for await (id, hash) in group {
                    if let hash { acc[id] = hash }
                }
                return acc
            }
            ImageHashCache.shared.saveHashes(computed)
            result.merge(computed) { _, new in new }
        }
        return result
    }

    // MARK: - 操作

    /// 归类：把选中的照片加入相册
    @MainActor
    func addImages(_ ids: [String], to album: Album) async {
        do {
            try await albumManager.add(assetIdentifiers: ids, to: album)
            albums = albumManager.albums
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 删除照片 → iOS 移入"最近删除"（对应 Android moveToTrash）
    func deleteImages(_ ids: [String]) async {
        let assets = ids.compactMap { repository.asset(withIdentifier: $0) }
        guard !assets.isEmpty else { return }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.deleteAssets(NSArray(array: assets))
            }
            await load()
        } catch {
            errorMessage = "删除失败：\(error.localizedDescription)"
        }
    }

    func createAlbum(name: String, color: Int64? = nil) async {
        do {
            _ = try await albumManager.createAlbum(name: name, color: color)
            albums = albumManager.albums
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map { index in
            Array(self[index..<Swift.min(index + size, count)])
        }
    }
}
