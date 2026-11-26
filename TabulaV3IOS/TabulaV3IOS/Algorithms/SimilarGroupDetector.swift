import Foundation

/// 相似照片组检测（对应 Android 版 SimilarGroupDetector）
///
/// 两阶段：元数据预筛（时间窗口 + 尺寸 + 大小 + 相册）→ 哈希验证 → 约束并查集聚类
/// 纯 Swift 实现，不依赖 UIKit/Photos，可直接在单元测试里跑。
final class SimilarGroupDetector {

    /// 时间窗口：只比较 10 分钟内的照片对
    static let timeWindowMs: Int64 = 10 * 60 * 1000
    /// 单组最大照片数
    static let maxGroupSize = 50
    /// 超过后提高合并门槛
    static let largeGroupThreshold = 30

    private let hashCache: ImageHashCache

    init(hashCache: ImageHashCache = .shared) {
        self.hashCache = hashCache
    }

    /// 检测相似组（对应 detectSimilarGroups）
    func detect(images: [ImageFile], hashes: [String: Int64]) -> [SimilarGroup] {
        guard images.count >= 2 else { return [] }

        let sorted = images.sorted { $0.dateModified < $1.dateModified }

        // 阶段1：元数据预筛
        var candidatePairs: [(Int, Int)] = []
        var candidateIndices = Set<Int>()
        for i in sorted.indices {
            for j in (i + 1)..<sorted.count {
                let timeDiff = sorted[j].dateModified - sorted[i].dateModified
                if timeDiff > Self.timeWindowMs { break }
                if metaScore(sorted[i], sorted[j]) >= 25 {
                    candidatePairs.append((i, j))
                    candidateIndices.insert(i)
                    candidateIndices.insert(j)
                }
            }
        }
        guard !candidatePairs.isEmpty else { return [] }

        // 阶段2：用传入的哈希（调用方负责从缓存/计算获得）做约束并查集
        var uf = ConstrainedUnionFind(count: sorted.count, images: sorted, hashes: hashes)
        for (i, j) in candidatePairs {
            let score = metaScore(sorted[i], sorted[j])
            let distance = hashDistance(sorted[i], sorted[j], hashes: hashes)
            guard shouldConnect(score: score, distance: distance) else { continue }

            let sizeI = uf.groupSize(i)
            let sizeJ = uf.groupSize(j)
            guard shouldConnectWithGroupSize(score: score, distance: distance, combinedSize: sizeI + sizeJ) else { continue }

            let repsI = uf.representatives(of: i)
            let repsJ = uf.representatives(of: j)
            let canJoinI = repsI.contains { rep in
                canJoin(newIndex: j, repIndex: rep, images: sorted, hashes: hashes)
            }
            let canJoinJ = repsJ.contains { rep in
                canJoin(newIndex: i, repIndex: rep, images: sorted, hashes: hashes)
            }
            if canJoinI && canJoinJ { uf.union(i, j) }
        }

        // 阶段3：收集结果
        var groups: [Int: [ImageFile]] = [:]
        for i in sorted.indices {
            let root = uf.find(i)
            groups[root, default: []].append(sorted[i])
        }
        return groups.values
            .filter { $0.count >= 2 }
            .map { SimilarGroup(images: $0) }
            .sorted { $0.size > $1.size }
    }

    // MARK: - 相似度评分

    /// 元数据分数（对应 calculateMetaScoreOnly / calculateSimilarityWithHash 的元数据部分）
    func metaScore(_ a: ImageFile, _ b: ImageFile) -> Float {
        var score: Float = 0
        let diffSeconds = abs(a.dateModified - b.dateModified) / 1000

        // 时间 0-25
        score += switch diffSeconds {
        case ..<5: 25
        case ..<30: 22
        case ..<60: 18
        case ..<180: 14
        case ..<300: 10
        case ..<600: 5
        default: 0
        }

        // 尺寸 0-20
        if a.actualWidth == b.actualWidth && a.actualHeight == b.actualHeight {
            score += 20
        } else {
            let aspectDiff = abs(a.aspectRatio - b.aspectRatio)
            if aspectDiff < 0.02 { score += 12 }
            else if aspectDiff < 0.1 { score += 6 }
        }

        // 文件大小 0-10
        let sizeDiffPercent = Float(abs(a.size - b.size)) / Float(max(a.size, 1))
        score += switch sizeDiffPercent {
        case ..<0.05: 10
        case ..<0.10: 8
        case ..<0.20: 5
        case ..<0.30: 2
        default: 0
        }

        // 同相册 0-5
        if let bucket = a.bucketDisplayName, bucket == b.bucketDisplayName { score += 5 }
        return score
    }

    private func hashDistance(_ a: ImageFile, _ b: ImageFile, hashes: [String: Int64]) -> Int? {
        guard let ha = hashes[a.id], let hb = hashes[b.id] else { return nil }
        return PerceptualHash.hammingDistance(ha, hb)
    }

    /// 连边判断（对应 shouldConnect）
    private func shouldConnect(score: Float, distance: Int?) -> Bool {
        guard let distance else { return false } // iOS 侧都能算到哈希，简化掉 Android 的 hash 缺失分支
        return switch distance {
        case ...6: score >= 15
        case ...10: score >= 30
        case ...14: score >= 45
        default: false
        }
    }

    private func shouldConnectWithGroupSize(score: Float, distance: Int?, combinedSize: Int) -> Bool {
        guard shouldConnect(score: score, distance: distance) else { return false }
        if combinedSize > Self.largeGroupThreshold {
            guard let d = distance, d <= 10, score >= 40 else { return false }
        }
        if combinedSize > Self.maxGroupSize - 5 {
            guard let d = distance, d <= 6 else { return false }
        }
        return true
    }

    private func canJoin(newIndex: Int, repIndex: Int, images: [ImageFile], hashes: [String: Int64]) -> Bool {
        let newPhoto = images[newIndex]
        let repPhoto = images[repIndex]
        let timeDiff = abs(newPhoto.dateModified - repPhoto.dateModified) / 1000
        let sameRes = newPhoto.actualWidth == repPhoto.actualWidth && newPhoto.actualHeight == repPhoto.actualHeight
        guard let d = hashDistance(newPhoto, repPhoto, hashes: hashes) else {
            return timeDiff <= 60 && sameRes
        }
        if d <= 8 { return true }
        if d <= 12 { return sameRes || timeDiff <= 120 }
        return false
    }
}

// MARK: - 约束并查集（对应 ConstrainedUnionFind）
private struct ConstrainedUnionFind {
    private var parent: [Int]
    private var rank: [Int]
    private var sizes: [Int]
    private var representatives: [[Int]]
    private let images: [ImageFile]
    private let hashes: [String: Int64]

    init(count: Int, images: [ImageFile], hashes: [String: Int64]) {
        self.parent = Array(0..<count)
        self.rank = Array(repeating: 0, count: count)
        self.sizes = Array(repeating: 1, count: count)
        self.representatives = Array(0..<count).map { [$0] }
        self.images = images
        self.hashes = hashes
    }

    mutating func find(_ x: Int) -> Int {
        if parent[x] != x { parent[x] = find(parent[x]) }
        return parent[x]
    }

    func groupSize(_ x: Int) -> Int {
        var x = x
        while parent[x] != x { x = parent[x] }
        return sizes[x]
    }

    func representatives(of x: Int) -> [Int] {
        var root = x
        while parent[root] != root { root = parent[root] }
        return representatives[root]
    }

    mutating func union(_ x: Int, _ y: Int) {
        var rx = find(x), ry = find(y)
        guard rx != ry else { return }
        let newSize = sizes[rx] + sizes[ry]
        guard newSize <= SimilarGroupDetector.maxGroupSize else { return }
        if rank[rx] < rank[ry] { swap(&rx, &ry) }
        parent[ry] = rx
        if rank[rx] == rank[ry] { rank[rx] += 1 }
        sizes[rx] = newSize
        representatives[rx] = Array(Set(representatives[rx] + representatives[ry]))
    }
}
