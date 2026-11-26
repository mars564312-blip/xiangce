import SwiftUI

/// 单张照片卡片（简化版 ImageCard）
struct PhotoCardView: View {
    let image: ImageFile
    private let repository = PhotoLibraryRepository()
    @State private var thumbnail: UIImage?

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(uiColor: .secondarySystemBackground))

            if let thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 20))
            } else {
                ProgressView()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(image.displayName)
                    .font(.caption.weight(.medium))
                Text("\(image.actualWidth)×\(image.actualHeight)")
                    .font(.caption2)
            }
            .padding(12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            .padding(12)
        }
        .task {
            let size = await UIScreen.main.scale > 2
                ? CGSize(width: 600, height: 600) : CGSize(width: 300, height: 300)
            let loaded = await withCheckedContinuation { continuation in
                _ = repository.requestThumbnail(for: image.assetIdentifier, targetSize: size) { img in
                    continuation.resume(returning: img)
                }
            }
            thumbnail = loaded
        }
    }
}
