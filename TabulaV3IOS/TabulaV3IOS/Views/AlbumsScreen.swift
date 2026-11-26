import SwiftUI

/// 图集列表（对应 Android CategorizedAlbumsView / AlbumViewScreen）
struct AlbumsScreen: View {
    @EnvironmentObject private var viewModel: PhotoLibraryViewModel
    @State private var showingCreate = false
    @State private var newAlbumName = ""

    private var gridColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 140), spacing: 16)]
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: gridColumns, spacing: 16) {
                ForEach(viewModel.albums.filter { !$0.isHidden }) { album in
                    NavigationLink(value: album.id) {
                        AlbumTile(album: album)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .navigationTitle("图集")
        .navigationDestination(for: String.self) { albumID in
            if let album = viewModel.albums.first(where: { $0.id == albumID }) {
                AlbumDetailView(album: album)
            }
        }
        .toolbar {
            Button { showingCreate = true } label: {
                Image(systemName: "plus")
            }
        }
        .alert("新建图集", isPresented: $showingCreate) {
            TextField("图集名称", text: $newAlbumName)
            Button("取消", role: .cancel) { newAlbumName = "" }
            Button("创建") {
                let name = newAlbumName.trimmingCharacters(in: .whitespaces)
                if !name.isEmpty {
                    Task { await viewModel.createAlbum(name: name) }
                }
                newAlbumName = ""
            }
        }
    }
}

private struct AlbumTile: View {
    let album: Album

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(album.color.map { Color(argb: $0).opacity(0.25) } ?? Color.accentColor.opacity(0.12))
                if let cover = album.coverAssetIdentifier {
                    ThumbnailView(identifier: cover)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    Image(systemName: "folder")
                        .font(.title)
                        .foregroundStyle(.secondary)
                }
            }
            .aspectRatio(1, contentMode: .fit)

            Text(album.name).font(.subheadline.weight(.medium)).lineLimit(1)
            Text("\(album.imageCount) 张").font(.caption).foregroundStyle(.secondary)
        }
    }
}

/// 复用缩略图加载（简化版）
struct ThumbnailView: View {
    let identifier: String
    private let repository = PhotoLibraryRepository()
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image { Image(uiImage: image).resizable().scaledToFill() }
            else { Color.secondary.opacity(0.1) }
        }
        .task {
            let loaded = await withCheckedContinuation { continuation in
                _ = repository.requestThumbnail(for: identifier, targetSize: CGSize(width: 240, height: 240)) { img in
                    continuation.resume(returning: img)
                }
            }
            image = loaded
        }
    }
}
