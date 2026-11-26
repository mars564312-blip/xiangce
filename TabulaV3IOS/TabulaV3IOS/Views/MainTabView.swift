import SwiftUI

/// 主 Tab 结构（Android 版用 Compose Navigation，iOS 用 TabView）
struct MainTabView: View {
    @EnvironmentObject private var viewModel: PhotoLibraryViewModel
    @EnvironmentObject private var permission: PhotoPermissionManager

    var body: some View {
        TabView {
            NavigationStack { DeckScreen() }
                .tabItem { Label("整理", systemImage: "rectangle.stack") }

            NavigationStack { AlbumsScreen() }
                .tabItem { Label("图集", systemImage: "folder.grid") }

            NavigationStack { SettingsScreen() }
                .tabItem { Label("设置", systemImage: "gearshape") }
        }
        .task { await viewModel.load() }
        .overlay {
            if viewModel.isLoading {
                ProgressView().padding(.bottom, 60)
            }
        }
        .alert("提示", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("好", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .sheet(isPresented: Binding(
            get: { permission.state == .limited },
            set: { _ in }
        )) {
            // iOS limited 权限提示：占位说明，真机上引导用户扩充可见照片范围
            VStack(spacing: 16) {
                Image(systemName: "photo.badge.plus").font(.largeTitle)
                Text("当前仅授权了部分照片").font(.headline)
                Text("可在系统设置中允许 Tabula 访问全部照片，或选择更多照片。")
                    .foregroundStyle(.secondary).multilineTextAlignment(.center)
                Button("选择更多照片") { permission.presentLimitedLibraryPicker() }
                    .buttonStyle(.borderedProminent)
            }
            .padding()
            .presentationDetents([.medium])
        }
    }
}
