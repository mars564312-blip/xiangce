import SwiftUI

/// 相似照片分组列表（对应 Android 推荐/相似检测界面）
struct SimilarGroupsView: View {
    @EnvironmentObject private var viewModel: PhotoLibraryViewModel

    var body: some View {
        Group {
            if viewModel.similarGroups.isEmpty {
                ContentUnavailableView("没有发现相似照片", systemImage: "square.on.square")
            } else {
                List(viewModel.similarGroups) { group in
                    NavigationLink {
                        ScrollView {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 4)], spacing: 4) {
                                ForEach(group.images) { image in
                                    ThumbnailView(identifier: image.assetIdentifier)
                                        .aspectRatio(1, contentMode: .fill)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                }
                            }
                            .padding(4)
                        }
                    } label: {
                        HStack {
                            Text("\(group.size) 张相似照片")
                            Spacer()
                            Text(durationLabel(group.durationMs)).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("相似照片")
    }

    private func durationLabel(_ ms: Int64) -> String {
        let minutes = ms / 60_000
        return minutes < 1 ? "1分钟内" : "\(minutes)分钟内"
    }
}
