import SwiftUI

/// 权限申请 / 被拒引导页（对应 Android 的权限请求流程 + OnboardingScreen）
struct PermissionView: View {
    @EnvironmentObject private var permission: PhotoPermissionManager

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "photo.stack")
                .font(.system(size: 64))
                .foregroundStyle(.tint)

            Text("Tabula 相册整理")
                .font(.title2.weight(.semibold))

            Text(permission.state == .denied || permission.state == .restricted
                 ? "需要在系统设置中开启照片访问权限，才能整理你的照片。"
                 : "Tabula 需要访问照片库，才能帮你快速归类整理照片。\n照片不会被上传，全部在本机处理。")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                if permission.state.needsPrompt {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    UIApplication.shared.open(url)
                } else {
                    Task { await permission.request() }
                }
            } label: {
                Text(permission.state.needsPrompt ? "前往系统设置" : "允许访问照片")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 32)

            Spacer()
        }
    }
}
