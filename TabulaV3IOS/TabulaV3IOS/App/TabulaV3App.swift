import SwiftUI

@main
struct TabulaV3App: App {
    @StateObject private var permission = PhotoPermissionManager.shared
    @StateObject private var viewModel = PhotoLibraryViewModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(permission)
                .environmentObject(viewModel)
                .task {
                    if permission.state == .notDetermined {
                        await permission.request()
                    }
                }
        }
    }
}

/// 根视图：权限门控 → 主界面
struct RootView: View {
    @EnvironmentObject private var permission: PhotoPermissionManager
    @EnvironmentObject private var viewModel: PhotoLibraryViewModel

    var body: some View {
        Group {
            if permission.state.canReadPhotos {
                MainTabView()
            } else {
                PermissionView()
            }
        }
        .animation(.default, value: permission.state)
    }
}
