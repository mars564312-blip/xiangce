import Foundation
import Photos

/// 相册管理器（替代 Android 版 AlbumManager + SystemAlbumSyncManager）
///
/// ## 模型差异（移植时最重要的认知转换）
/// Android：图集 = 文件夹，归类 = 把图片**复制**到 Pictures/Tabula/{name}/，
///         再用"清理原图"删掉源文件释放空间。
/// iOS：    图集 = PHAssetCollection，归类 = 把 PHAsset **加入**相册。
///         同一张照片可属于多个相册且不产生文件副本 —— 不需要复制、不需要清理原图。
@MainActor
final class AlbumManager: ObservableObject {
    static let shared = AlbumManager()

    @Published private(set) var albums: [Album] = []
    @Published private(set) var isBusy = false
    @Published private(set) var errorMessage: String?

    private let repository = PhotoLibraryRepository()
    private let metadataStore = AlbumMetadataStore.shared

    private init() {}

    // MARK: - 加载

    func loadAlbums() async {
        let systemAlbums = await repository.loadAllAlbums()
        let metadata = metadataStore.allMetadata()

        // 合并 Photos 真实相册 + 仅有元数据的空相册（Android refreshAlbumsFromSystem 的等价物）
        let merged = systemAlbums.map { album -> Album in
            let meta = metadata[album.name]
            return Album(
                id: album.id,
                name: album.name,
                coverAssetIdentifier: album.coverAssetIdentifier,
                color: meta?.color,
                textColor: meta?.textColor,
                order: meta?.order ?? Int.max,
                imageCount: album.imageCount,
                isSystemAlbum: true,
                isHidden: meta?.isHidden ?? false,
                isExcludedFromRecommend: meta?.isExcludedFromRecommend ?? false
            )
        }

        let systemNames = Set(systemAlbums.map(\.name))
        let metadataOnly = metadata.values
            .filter { !systemNames.contains($0.name) }
            .map { meta in
                Album(
                    id: meta.id,
                    name: meta.name,
                    color: meta.color,
                    order: meta.order,
                    isSystemAlbum: false,
                    isHidden: meta.isHidden,
                    isExcludedFromRecommend: meta.isExcludedFromRecommend
                )
            }

        albums = (merged + metadataOnly)
            .sorted { ($0.order, $0.name) < ($1.order, $1.name) }
    }

    // MARK: - CRUD

    /// 创建相册（对应 createAlbum：创建系统文件夹 + 保存元数据）
    func createAlbum(name: String, color: Int64? = nil) async throws -> Album {
        isBusy = true
        defer { isBusy = false }

        // 在 change block 内捕获 placeholder 的 localIdentifier，成功后它就是新相册的真实 ID
        var capturedIdentifier: String?
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: name)
                capturedIdentifier = request.placeholderForCreatedAssetCollection.localIdentifier
            } completionHandler: { success, error in
                if success { continuation.resume() }
                else { continuation.resume(throwing: error ?? AlbumError.creationFailed) }
            }
        }

        guard let identifier = capturedIdentifier else {
            throw AlbumError.creationFailed
        }

        let meta = AlbumMetadata(name: name, color: color, order: albums.count + 1)
        metadataStore.save(meta)
        await loadAlbums()
        return albums.first { $0.id == identifier }
            ?? Album(id: identifier, name: name, color: color, order: meta.order, isSystemAlbum: true)
    }

    /// 重命名相册（对应 renameSystemAlbum）
    func renameAlbum(_ album: Album, to newName: String) async throws {
        guard album.isSystemAlbum else {
            var meta = metadataStore.allMetadata()[album.name] ?? AlbumMetadata(name: album.name)
            meta.name = newName
            metadataStore.save(meta)
            await loadAlbums()
            return
        }
        let identifier = album.id
        PHPhotoLibrary.shared().performChanges {
            let collections = PHAssetCollection.fetchAssetCollections(
                withLocalIdentifiers: [identifier], options: nil
            )
            if let collection = collections.firstObject,
               let changeRequest = PHAssetCollectionChangeRequest(for: collection) {
                changeRequest.title = newName
            }
        }
        await loadAlbums()
    }

    /// 删除相册：Photos 侧删除相册**不会删除里面的照片**（照片仍在"所有照片"里）
    /// 与 Android deleteEmptyAlbum 语义一致
    func deleteAlbum(_ album: Album) async throws {
        guard album.isSystemAlbum else {
            metadataStore.remove(name: album.name)
            await loadAlbums()
            return
        }
        let identifier = album.id
        PHPhotoLibrary.shared().performChanges {
            let collections = PHAssetCollection.fetchAssetCollections(
                withLocalIdentifiers: [identifier], options: nil
            )
            if let collection = collections.firstObject {
                PHAssetCollectionChangeRequest.deleteAssetCollections(NSArray(array: [collection]))
            }
        }
        metadataStore.remove(name: album.name)
        await loadAlbums()
    }

    // MARK: - 归类图片

    /// 归类：把照片加入相册（对应 addImageToAlbum / queueImageToAlbum + commit）
    /// iOS 不复制文件：把 PHAsset 加入 PHAssetCollection 只是建立关联。
    func add(assetIdentifiers: [String], to album: Album) async throws {
        guard album.isSystemAlbum else { throw AlbumError.albumNotReady }
        let collectionIdentifier = album.id
        let assets = assetIdentifiers.compactMap { repository.asset(withIdentifier: $0) }
        guard !assets.isEmpty else { return }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges {
                let collections = PHAssetCollection.fetchAssetCollections(
                    withLocalIdentifiers: [collectionIdentifier], options: nil
                )
                if let collection = collections.firstObject,
                   let changeRequest = PHAssetCollectionChangeRequest(for: collection) {
                    changeRequest.addAssets(NSArray(array: assets))
                }
            } completionHandler: { success, error in
                if success { continuation.resume() }
                else { continuation.resume(throwing: error ?? AlbumError.operationFailed) }
            }
        }
        await loadAlbums()
    }

    /// 从相册移除（不从照片库删除）
    func remove(assetIdentifiers: [String], from album: Album) async throws {
        guard album.isSystemAlbum else { return }
        let collectionIdentifier = album.id
        let assets = assetIdentifiers.compactMap { repository.asset(withIdentifier: $0) }
        guard !assets.isEmpty else { return }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges {
                let collections = PHAssetCollection.fetchAssetCollections(
                    withLocalIdentifiers: [collectionIdentifier], options: nil
                )
                if let collection = collections.firstObject,
                   let changeRequest = PHAssetCollectionChangeRequest(for: collection) {
                    changeRequest.removeAssets(NSArray(array: assets))
                }
            } completionHandler: { success, error in
                if success { continuation.resume() }
                else { continuation.resume(throwing: error ?? AlbumError.operationFailed) }
            }
        }
        await loadAlbums()
    }

    // MARK: - 元数据

    func updateMetadata(of album: Album, color: Int64?, isHidden: Bool, isExcluded: Bool) {
        var meta = metadataStore.allMetadata()[album.name]
            ?? AlbumMetadata(name: album.name, id: album.isSystemAlbum ? album.id : nil)
        meta.color = color
        meta.isHidden = isHidden
        meta.isExcludedFromRecommend = isExcluded
        metadataStore.save(meta)
        Task { await loadAlbums() }
    }
}

enum AlbumError: LocalizedError {
    case creationFailed
    case albumNotReady
    case operationFailed

    var errorDescription: String? {
        switch self {
        case .creationFailed: return "创建相册失败，请检查照片库权限"
        case .albumNotReady: return "相册尚未同步到照片库"
        case .operationFailed: return "操作失败，请稍后重试"
        }
    }
}
