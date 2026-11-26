import SwiftUI

/// 设置页（对应 Android SettingsScreen 骨架）
struct SettingsScreen: View {
    @EnvironmentObject private var permission: PhotoPermissionManager
    @EnvironmentObject private var viewModel: PhotoLibraryViewModel

    var body: some View {
        List {
            Section("照片权限") {
                Label {
                    VStack(alignment: .leading) {
                        Text("访问状态")
                        Text(permission.state.canReadPhotos ? "已授权" : "未授权")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: permission.state.canReadPhotos ? "checkmark.shield" : "shield.slash")
                }
                if permission.state == .limited {
                    Button("选择更多照片") { permission.presentLimitedLibraryPicker() }
                }
            }

            Section("整理") {
                NavigationLink {
                    SimilarGroupsView()
                } label: {
                    Label("相似照片（\(viewModel.similarGroups.count) 组）", systemImage: "square.on.square")
                }
            }

            Section("数据") {
                Button("清除哈希缓存", role: .destructive) {
                    ImageHashCache.shared.removeAll()
                }
            }

            Section("关于") {
                Text("Tabula V3 iOS 移植骨架 · version 3.3.3")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("设置")
    }
}
