import SwiftUI

/// 卡片整理主界面（对应 Android 版 DeckScreen）
/// 骨架：展示待整理照片卡片，左右滑动选择目标图集后归类
struct DeckScreen: View {
    @EnvironmentObject private var viewModel: PhotoLibraryViewModel

    @State private var currentIndex = 0
    @State private var selectedAlbumID: String?
    @State private var showingAlbumPicker = false

    private var pendingImages: [ImageFile] {
        // Android 靠路径前缀排除已归类照片；iOS 里用"是否属于任一 Tabula 图集"判断
        let groupedIDs = Set(viewModel.similarGroups.flatMap { $0.images.map(\.id) })
        return viewModel.images.filter { !groupedIDs.contains($0.id) }
    }

    var body: some View {
        VStack {
            if pendingImages.isEmpty {
                ContentUnavailableView(
                    "没有待整理的照片",
                    systemImage: "checkmark.circle",
                    description: Text("所有照片都已归类，或相册为空")
                )
            } else {
                header
                cardStack
                actionBar
            }
        }
        .navigationTitle("整理")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("排序", selection: $viewModel.sortOrder) {
                        ForEach(SortOrder.allCases) { order in
                            Text(order.label).tag(order)
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                }
            }
        }
        .sheet(isPresented: $showingAlbumPicker) {
            AlbumPickerSheet(selectedID: $selectedAlbumID)
        }
        .task(id: viewModel.sortOrder) { await viewModel.load() }
    }

    private var header: some View {
        HStack {
            Text("\(max(0, pendingImages.count - currentIndex)) 张待整理")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal)
    }

    private var cardStack: some View {
        TabView(selection: $currentIndex) {
            ForEach(Array(pendingImages.enumerated()), id: \.element.id) { index, image in
                PhotoCardView(image: image)
                    .tag(index)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(maxHeight: .infinity)
    }

    private var actionBar: some View {
        HStack(spacing: 16) {
            Button {
                // 简化：删除当前照片（iOS 进"最近删除"，可恢复）
                guard let image = pendingImages[safe: currentIndex] else { return }
                Task { await viewModel.deleteImages([image.id]) }
                currentIndex = min(currentIndex + 1, pendingImages.count - 1)
            } label: {
                Label("删除", systemImage: "trash")
            }
            .buttonStyle(.bordered)

            Button {
                showingAlbumPicker = true
            } label: {
                Label("归类到图集", systemImage: "folder.badge.plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
