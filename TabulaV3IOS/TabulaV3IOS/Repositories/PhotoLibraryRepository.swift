import Foundation
import Photos

/// 本地照片仓库（替代 Android 版 LocalImageRepository 的 MediaStore 查询）
///
/// Android 用 ContentResolver.query(MediaStore.Images...) 拿 Cursor；
/// iOS 用 PHAsset.fetchAssets 拿 PHFetchResult<PHAsset>，再映射为纯值模型 ImageFile。
/// 关键设计：返回的 ImageFile 不含 PHAsset 引用，Photos 交互统一走 asset(withIdentifier:)。
final class PhotoLibraryRepository {

    private let imageManager = PHImageManager.default()

    /// 加载全部照片（对应 loadAllData）
    /// - Tabula 图集内的照片无需像 Android 那样靠路径前缀排除，
    ///   因为 iOS 的照片加入 Album 不产生副本、不新增 asset。
    func loadAllImages(sortOrder: SortOrder = .dateModifiedDesc) async -> [ImageFile] {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.includeHiddenAssets = false
        options.includeAllBurstAssets = false

        let assets = PHAsset.fetchAssets(with: .image, options: options)
        var result: [ImageFile] = []
        result.reserveCapacity(assets.count)

        assets.enumerateObjects { asset, _, _ in
            // isTrashed 为 iOS 14+ API，本工程部署目标 iOS 17，可直接使用
            guard !asset.isTrashed else { return }

            let collectionNames = Self.albumNames(for: asset)
            result.append(Self.map(asset: asset, bucketDisplayName: collectionNames.first))
        }

        return sortOrder.sort(result)
    }

    /// 按相册加载照片（对应 getImagesByBucket）
    func loadImages(in album: Album) async -> [ImageFile] {
        guard let id = album.isSystemAlbum ? album.id : nil,
              let collection = PHAssetCollection.fetchAssetCollections(
                  withLocalIdentifiers: [id], options: nil
              ).firstObject else { return [] }

        let assets = PHAsset.fetchAssets(in: collection, options: nil)
        var result: [ImageFile] = []
        assets.enumerateObjects { asset, _, _ in
            result.append(Self.map(asset: asset, bucketDisplayName: collection.localizedTitle))
        }
        return result.sorted { $0.dateModified > $1.dateModified }
    }

    /// 加载全部系统相册及封面（对应 getAllBucketsWithInfo）
    func loadAllAlbums() async -> [Album] {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "localizedTitle", ascending: true)]

        let collections = PHAssetCollection.fetchAssetCollections(
            with: .album, subtype: .any, options: options
        )
        var albums: [Album] = []
        collections.enumerateObjects { collection, _, _ in
            let assets = PHAsset.fetchAssets(in: collection, options: nil)
            guard assets.count > 0 else { return }
            albums.append(Album(
                id: collection.localIdentifier,
                name: collection.localizedTitle ?? "未命名",
                coverAssetIdentifier: assets.firstObject?.localIdentifier,
                imageCount: assets.count,
                isSystemAlbum: true
            ))
        }
        return albums
    }

    /// 懒加载缩略图（Android 用 Coil，iOS 用 PHImageManager + NSCache）
    func requestThumbnail(
        for assetIdentifier: String,
        targetSize: CGSize,
        completion: @escaping (UIImage?) -> Void
    ) -> PHImageRequestID {
        guard let asset = asset(withIdentifier: assetIdentifier) else {
            completion(nil)
            return 0
        }
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true

        return imageManager.requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: options
        ) { image, _ in completion(image) }
    }

    func cancelThumbnail(requestID: PHImageRequestID) {
        imageManager.cancelImageRequest(requestID)
    }

    func asset(withIdentifier id: String) -> PHAsset? {
        PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject
    }

    // MARK: - 映射

    private static func map(asset: PHAsset, bucketDisplayName: String?) -> ImageFile {
        let creationDate = asset.creationDate ?? asset.modificationDate ?? Date()
        return ImageFile(
            id: asset.localIdentifier,
            assetIdentifier: asset.localIdentifier,
            displayName: asset.originalFilename ?? "IMG_\(Int64(creationDate.milliseconds)).jpg",
            dateModified: Int64((asset.modificationDate ?? creationDate).milliseconds),
            size: 0, // PHAsset 不直接暴露文件大小；按需用 requestImageDataAndOrientation 取
            width: asset.pixelWidth,
            height: asset.pixelHeight,
            bucketDisplayName: bucketDisplayName,
            orientation: Int(asset.orientation.rawValue) // 0 = 未旋转，与 Android EXIF 语义近似
        )
    }

    private static func albumNames(for asset: PHAsset) -> [String] {
        let collections = PHAssetCollection.fetchAssetCollectionsContaining(
            asset, with: .album, options: nil
        )
        var names: [String] = []
        collections.enumerateObjects { collection, _, _ in
            if let title = collection.localizedTitle { names.append(title) }
        }
        return names
    }
}
