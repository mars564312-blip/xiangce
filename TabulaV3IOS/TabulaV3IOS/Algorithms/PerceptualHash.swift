import Foundation
import CoreGraphics
import UIKit

/// 感知哈希计算（对应 Android 版 PerceptualHash）
///
/// dHash 算法（与 Android 版保持一致，确保跨端哈希值可比）：
/// 1. 缩放到 9x8
/// 2. 转灰度 BT.601
/// 3. 比较相邻像素：左 > 右 → 1，否则 → 0
/// 4. 生成 64-bit 哈希
///
/// 注意：Android 版会先读 EXIF 方向并旋转；iOS 的 UIImage 归一化后方向已正确，
/// 用 CGImage 渲染时方向由 UIImage 处理，无需再手动套 Matrix。
enum PerceptualHash {

    /// 从 CGImage 计算 dHash，纯函数，便于单元测试
    static func computeDHash(_ cgImage: CGImage) -> Int64? {
        let width = 9
        let height = 8
        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return nil }

        context.interpolationQuality = .medium
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let data = context.data else { return nil }
        let pixels = data.bindMemory(to: UInt8.self, capacity: width * height)

        func gray(_ x: Int, _ y: Int) -> Int {
            Int(pixels[y * width + x])
        }

        var hash: Int64 = 0
        var bit = 0
        for y in 0..<height {
            for x in 0..<(width - 1) {
                if gray(x, y) > gray(x + 1, y) {
                    hash |= (1 << bit)
                }
                bit += 1
            }
        }
        return hash
    }

    /// 便捷入口：从 UIImage 计算
    static func computeDHash(_ image: UIImage) -> Int64? {
        guard let cgImage = image.cgImage else { return nil }
        return computeDHash(cgImage)
    }

    /// 汉明距离（对应 hammingDistance；Swift 的 nonisolated bitWidth 用法）
    static func hammingDistance(_ a: Int64, _ b: Int64) -> Int {
        (a ^ b).nonzeroBitCount
    }

    /// 异步从 PHAsset 计算（加载 64px 缩略图后计算）
    static func computeDHash(
        assetIdentifier: String,
        repository: PhotoLibraryRepository
    ) async -> Int64? {
        await withCheckedContinuation { continuation in
            repository.requestThumbnail(for: assetIdentifier, targetSize: CGSize(width: 64, height: 64)) { image in
                continuation.resume(returning: image.flatMap { computeDHash($0) })
            }
        }
    }
}
