import Foundation

/// 图片领域模型
///
/// 对应 Android 版 `com.tabula.v3.data.model.ImageFile`。
/// 刻意设计成**不依赖 Photos 框架**的纯值类型：这样算法层（dHash / 相似检测）
/// 可以原样抽成 Kotlin Multiplatform 共享模块，也能脱离模拟器做单元测试。
///
/// - id: 稳定标识。Android 用 MediaStore 的 Long，iOS 用 PHAsset.localIdentifier(String)
/// - assetIdentifier: PHAsset.localIdentifier，Photos 层据此加载图片/缩略图
struct ImageFile: Identifiable, Hashable, Codable {
    let id: String
    let assetIdentifier: String
    let displayName: String
    /// 修改/拍摄时间戳（毫秒），与 Android dateModified 对齐
    let dateModified: Int64
    let size: Int64
    let width: Int
    let height: Int
    /// 所属相册名（iOS 对应 PHAssetCollection.localizedTitle）
    let bucketDisplayName: String?
    /// EXIF 方向角度（0/90/180/270）
    let orientation: Int

    /// EXIF 旋转后是否需要交换宽高
    private var needSwapDimensions: Bool { orientation == 90 || orientation == 270 }

    var actualWidth: Int { needSwapDimensions ? height : width }
    var actualHeight: Int { needSwapDimensions ? width : height }
    var isPortrait: Bool { actualHeight > actualWidth }
    var aspectRatio: Float {
        actualWidth > 0 && actualHeight > 0 ? Float(actualWidth) / Float(actualHeight) : 0.75
    }
    var hasDimensionInfo: Bool { width > 0 && height > 0 }

    /// 供 SwiftUI 列表/网格稳定排序
    var sortDate: Date { Date(milliseconds: dateModified) }
}

// MARK: - Date 毫秒互转（与 Android System.currentTimeMillis 对齐）
extension Date {
    init(milliseconds: Int64) {
        self.init(timeIntervalSince1970: TimeInterval(milliseconds) / 1000.0)
    }

    var milliseconds: Int64 {
        Int64(timeIntervalSince1970 * 1000.0)
    }
}
