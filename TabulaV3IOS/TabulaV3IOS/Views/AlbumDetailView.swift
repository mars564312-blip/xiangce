import SwiftUI

/// 图集详情（对应 Android AlbumViewScreen）
struct AlbumDetailView: View {
    let album: Album
    @EnvironmentObject private var viewModel: PhotoLibraryViewModel
    @State private var images: [ImageFile] = []

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 4)]

    var body: some View {
        ScrollView {
            if images.isEmpty {
                ContentUnavailableView("图集为空", systemImage: "photo")
            } else {
                LazyVGrid(columns: columns, spacing: 4) {
                    ForEach(images) { image in
                        ThumbnailView(identifier: image.assetIdentifier)
                            .aspectRatio(1, contentMode: .fill)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
                .padding(4)
            }
        }
        .navigationTitle(album.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            images = await PhotoLibraryRepository().loadImages(in: album)
        }
    }
}
