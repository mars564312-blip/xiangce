import Foundation

/// 相似照片组（对应 Android 版 SimilarGroup）
struct SimilarGroup: Identifiable {
    let id: String
    let images: [ImageFile]
    let startTime: Int64
    let endTime: Int64

    var size: Int { images.count }
    var durationMs: Int64 { endTime - startTime }

    init(images: [ImageFile]) {
        self.images = images.sorted { $0.dateModified < $1.dateModified }
        self.startTime = images.map(\.dateModified).min() ?? 0
        self.endTime = images.map(\.dateModified).max() ?? 0
        self.id = "\(startTime)_\(images.first?.id ?? "")"
    }
}

/// 排序方式（对应 Android LocalImageRepository.SortOrder）
enum SortOrder: String, CaseIterable, Identifiable {
    case dateModifiedDesc = "date_desc"
    case dateModifiedAsc = "date_asc"
    case nameAsc = "name_asc"
    case nameDesc = "name_desc"
    case sizeDesc = "size_desc"
    case sizeAsc = "size_asc"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .dateModifiedDesc: return "最新在前"
        case .dateModifiedAsc: return "最早在前"
        case .nameAsc: return "名称升序"
        case .nameDesc: return "名称降序"
        case .sizeDesc: return "最大在前"
        case .sizeAsc: return "最小在前"
        }
    }

    func sort(_ images: [ImageFile]) -> [ImageFile] {
        switch self {
        case .dateModifiedDesc: return images.sorted { $0.dateModified > $1.dateModified }
        case .dateModifiedAsc: return images.sorted { $0.dateModified < $1.dateModified }
        case .nameAsc: return images.sorted { $0.displayName < $1.displayName }
        case .nameDesc: return images.sorted { $0.displayName > $1.displayName }
        case .sizeDesc: return images.sorted { $0.size > $1.size }
        case .sizeAsc: return images.sorted { $0.size < $1.size }
        }
    }
}
