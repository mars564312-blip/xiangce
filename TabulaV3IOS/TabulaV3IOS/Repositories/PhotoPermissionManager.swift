import Photos
import SwiftUI

/// 照片库权限状态（对应 Android 版 MediaPermissionPolicy）
///
/// 这是 iOS 与 Android 差异最大的地方之一：
/// - Android 13+ 是 READ_MEDIA_IMAGES / READ_MEDIA_VISUAL_USER_SELECTED
/// - iOS 14+ 的 `.limited` 只授权部分照片，需要额外引导用户用
///   PHPicker 或 presentLimitedLibraryPicker 扩充可见范围
enum PhotoPermissionState {
    case notDetermined
    case restricted
    case denied
    case limited
    case authorized

    var needsPrompt: Bool {
        switch self {
        case .denied, .restricted: return true
        default: return false
        }
    }

    var canReadPhotos: Bool {
        switch self {
        case .authorized, .limited: return true
        default: return false
        }
    }
}

@MainActor
final class PhotoPermissionManager: ObservableObject {
    static let shared = PhotoPermissionManager()

    @Published private(set) var state: PhotoPermissionState = .notDetermined

    private init() {
        refresh()
    }

    func refresh() {
        state = Self.map(PHPhotoLibrary.authorizationStatus(for: .readWrite))
    }

    /// 请求读写权限。Info.plist 必须包含：
    /// NSPhotoLibraryUsageDescription / NSPhotoLibraryAddUsageDescription
    func request() async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        state = Self.map(status)
    }

    /// limited 模式下打开系统"选择更多照片"面板
    /// 注意：需在真机 presentingViewController 上调用；SwiftUI 用 UIViewControllerRepresentable 包装
    func presentLimitedLibraryPicker() {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first?.rootViewController else { return }
        PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: root)
    }

    private static func map(_ status: PHAuthorizationStatus) -> PhotoPermissionState {
        switch status {
        case .notDetermined: return .notDetermined
        case .restricted: return .restricted
        case .denied: return .denied
        case .limited: return .limited
        case .authorized: return .authorized
        @unknown default: return .notDetermined
        }
    }
}
