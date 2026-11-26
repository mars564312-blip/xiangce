import SwiftUI

/// 图集选择弹层（对应 Android AlbumSelectionSheet）
struct AlbumPickerSheet: View {
    @EnvironmentObject private var viewModel: PhotoLibraryViewModel
    @Binding var selectedID: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(viewModel.albums.filter { !$0.isHidden }) { album in
                Button {
                    selectedID = album.id
                    dismiss()
                } label: {
                    HStack {
                        if let color = album.color {
                            Circle().fill(Color(argb: color)).frame(width: 14, height: 14)
                        }
                        Text(album.name)
                        Spacer()
                        Text("\(album.imageCount)").foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("选择图集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

/// UIColor ARGB(Int64) → SwiftUI Color
extension Color {
    init(argb: Int64) {
        let a = CGFloat((argb >> 24) & 0xFF) / 255
        let r = CGFloat((argb >> 16) & 0xFF) / 255
        let g = CGFloat((argb >> 8) & 0xFF) / 255
        let b = CGFloat(argb & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}
