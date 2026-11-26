import Foundation

/// 同步模式（对应 Android 的 SyncMode）
enum SyncMode: String, Codable {
    /// 复制：iOS 里指"把照片同时加入相册"，不产生文件副本
    case copy
    /// 移动：从原相册移除再加入目标相册
    case move
}

/// 相册（图集）模型
///
/// 对应 Android 版 `com.tabula.v3.data.model.Album`。
/// 关键差异：iOS 里相册 = PHAssetCollection，一张照片可同时属于多个相册，
/// 加入相册不复制文件。因此 Android 的 systemAlbumPath / 清理原图机制在这里没有对应物。
struct Album: Identifiable, Hashable, Codable {
    /// iOS 用 PHAssetCollection.localIdentifier；纯元数据相册用 UUID
    let id: String
    let name: String
    let coverAssetIdentifier: String?
    /// ARGB 颜色（Int64，对应 Android 的 Long 颜色值）
    let color: Int64?
    let textColor: Int64?
    let emoji: String?
    let order: Int
    let createdAt: Int64
    let imageCount: Int
    /// 是否为 Photos 里的真实相册（false 表示只有元数据、尚无照片）
    let isSystemAlbum: Bool
    let isHidden: Bool
    let isExcludedFromRecommend: Bool

    init(
        id: String = UUID().uuidString,
        name: String,
        coverAssetIdentifier: String? = nil,
        color: Int64? = nil,
        textColor: Int64? = nil,
        emoji: String? = nil,
        order: Int = 0,
        createdAt: Int64 = Date().milliseconds,
        imageCount: Int = 0,
        isSystemAlbum: Bool = false,
        isHidden: Bool = false,
        isExcludedFromRecommend: Bool = false
    ) {
        self.id = id
        self.name = name
        self.coverAssetIdentifier = coverAssetIdentifier
        self.color = color
        self.textColor = textColor
        self.emoji = emoji
        self.order = order
        self.createdAt = createdAt
        self.imageCount = imageCount
        self.isSystemAlbum = isSystemAlbum
        self.isHidden = isHidden
        self.isExcludedFromRecommend = isExcludedFromRecommend
    }

    /// 对应 Android Album.PRESET_COLORS（Material 3 风格）
    static let presetColors: [Int64] = [
        0xFFE57373, 0xFFFF8A65, 0xFFFFD54F, 0xFF81C784, 0xFF4FC3F7,
        0xFF7986CB, 0xFFBA68C8, 0xFFF06292, 0xFF90A4AE, 0xFFA1887F
    ]

    static let presetEmojis = ["📷", "🌅", "🏠", "🎉", "✈️", "🍔", "🐱", "🌸", "⭐", "💼"]
}
