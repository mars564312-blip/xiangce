# Tabula V3 — iOS 移植骨架

这是从 Android 版（`com.tabula.v3`，Kotlin + Jetpack Compose，v3.3.3）移植到 iOS 的 **SwiftUI 工程骨架**。
目标是先把架构、数据层、核心算法和主要界面立起来，可在 Xcode 中直接编译运行，再逐步补齐细节。

---

## 一、快速开始

1. 用 **Mac + Xcode 15+** 打开 `TabulaV3IOS.xcodeproj`。
2. 选择模拟器或真机（照片库权限建议真机测试），按 `Cmd+R` 运行。
3. 首次启动会申请照片库权限；iOS 14+ 若选"部分照片"，骨架里有引导扩充可见范围的入口。
4. 若修改/新增 Swift 文件，重新运行一次 `python3 generate_pbxproj.py` 刷新工程文件（脚本在工程根目录）。

> 本工程最低部署目标 iOS 17，Swift 5.10，无第三方依赖。

---

## 二、最重要的模型差异（先读这段）

Android 版的核心设计是：

> 图集 = 系统文件夹 `Pictures/Tabula/{名字}`，归类照片 = **复制文件**到该文件夹，
> 原图位置记录在 `source_images.json`，清理时用"清理原图"删掉源文件释放空间。

**iOS 不能照搬这套**，因为沙盒不允许 App 往系统照片目录写文件夹，而且 Photos 框架的模型本身就不同：

| 概念 | Android（MediaStore） | iOS（Photos 框架） |
|---|---|---|
| 相册 | 文件夹（bucket） | `PHAssetCollection` |
| 一张照片属于多个相册 | 需复制多份文件 | 原生支持，同一 asset 可加入多个相册 |
| 归类照片 | 复制文件 + 记录原图 | `PHAssetCollectionChangeRequest.addAssets` |
| 删除/回收站 | `createTrashRequest` + 自管回收站 | `PHAssetChangeRequest.deleteAssets` → 系统"最近删除" |
| 读图 | `ContentResolver.query` + Cursor | `PHAsset.fetchAssets` + `PHFetchResult` |
| 缩略图 | Coil | `PHImageManager.requestImage` |
| 权限 | `READ_MEDIA_IMAGES` 等运行时权限 | `PHPhotoLibrary.requestAuthorization`（含 `.limited` 部分授权） |
| 小组件 | `TabulaWidgetProvider` (AppWidget) | WidgetKit（**未移植**） |
| 桌面快捷方式 | `shortcuts.xml` | App Shortcuts（**未移植**） |

**结论**：Android 的"复制 + 清理原图"机制在 iOS 上整体消失，这也意味着 iOS 版不会有重复占空间的照片。

---

## 三、模块映射（Android → iOS）

| Android 文件 | iOS 对应文件 | 复用度 |
|---|---|---|
| `data/model/ImageFile.kt` | `Models/ImageFile.swift` | 字段几乎 1:1，id 由 Long 换成 String |
| `data/model/Album.kt` | `Models/Album.swift` | 保留颜色/排序/隐藏；去掉 systemAlbumPath |
| `data/model/SyncMode.kt` | `Models/Album.swift` 内枚举 | 语义调整：iOS 的 copy/move 不产生文件副本 |
| `data/repository/LocalImageRepository.kt` | `Repositories/PhotoLibraryRepository.swift` | 重写：MediaStore → PHAsset |
| `data/repository/SystemAlbumSyncManager.kt` | `Repositories/AlbumManager.swift` | 重写：文件夹 → PHAssetCollection |
| `data/repository/AlbumManager.kt` | `Repositories/AlbumManager.swift` + `AlbumMetadataStore.swift` | 逻辑拆分：相册操作 + 元数据持久化 |
| `data/repository/FileOperationManager.kt` | `ViewModels/PhotoLibraryViewModel.swift` 的 `deleteImages` | 简化：系统回收站替代自管回收站 |
| `data/repository/RecycleBinManager.kt` | —（不需要） | iOS 用系统"最近删除" |
| `permission/MediaPermissionPolicy.kt` | `Repositories/PhotoPermissionManager.swift` | 重写，需处理 `.limited` |
| `data/cache/ImageHashCache.kt` | `Repositories/ImageHashCache.swift` | 机制相同，存储换成 Application Support JSON |
| `data/repository/PerceptualHash.kt` | `Algorithms/PerceptualHash.swift` | 算法 1:1 移植，CGImage 替代 Bitmap |
| `data/repository/SimilarGroupDetector.kt` | `Algorithms/SimilarGroupDetector.swift` | 算法 1:1 移植，并查集/评分阈值一致 |
| `data/repository/RecommendationEngine.kt` | —（待移植） | 见待办 |
| `ui/screens/DeckScreen.kt` | `Views/DeckScreen.swift` | 界面骨架 |
| `ui/screens/AlbumViewScreen.kt` | `Views/AlbumsScreen.swift` + `AlbumDetailView.swift` | 界面骨架 |
| `ui/components/ImageCard.kt` 等玻璃拟态组件 | `Views/Components/` | 未还原视觉，先用系统组件 |
| `widget/TabulaWidgetProvider.kt` | —（待移植） | 需 WidgetKit |
| `service/FluidCloudService.kt` | —（iOS 无对应） | 这是 ColorOS 专属能力 |

---

## 四、代码结构

```
TabulaV3IOS/
├── App/
│   └── TabulaV3App.swift          # @main 入口 + 权限门控
├── Models/                         # 纯值类型，不依赖 Photos（便于日后抽 KMP 共享层）
│   ├── ImageFile.swift
│   ├── Album.swift
│   └── SimilarGroup.swift
├── Repositories/
│   ├── PhotoLibraryRepository.swift   # PHAsset 读图/缩略图
│   ├── AlbumManager.swift             # PHAssetCollection CRUD + 归类
│   ├── AlbumMetadataStore.swift       # 元数据 JSON 持久化
│   ├── PhotoPermissionManager.swift   # 权限（含 limited）
│   └── ImageHashCache.swift           # 哈希缓存
├── Algorithms/                     # 纯 Swift 算法，可单测、可抽共享层
│   ├── PerceptualHash.swift
│   └── SimilarGroupDetector.swift
├── ViewModels/
│   └── PhotoLibraryViewModel.swift
├── Views/
│   ├── MainTabView.swift / DeckScreen.swift / AlbumsScreen.swift
│   ├── AlbumDetailView.swift / SimilarGroupsView.swift / SettingsScreen.swift
│   └── Components/PhotoCardView.swift / AlbumPickerSheet.swift
└── Resources/Info.plist + Assets.xcassets
```

---

## 五、待办清单（按优先级）

**P0 — 让核心流程可用**
1. 补全 `PhotoLibraryRepository` 中 `size` 字段（PHAsset 不直接暴露，用 `requestImageDataAndOrientation` 异步取）。
2. `PhotoLibraryViewModel.pendingImages` 目前用"是否属于相似组"近似排除已整理照片；应改为按"是否属于任一 Tabula 图集"过滤（与 Android `getAllImagesExcludingTabulaAlbums` 对齐）。
3. 归类操作接上 `AlbumPickerSheet` 的 `selectedID`——目前选中后只关闭弹层，未调用 `addImages`。
4. 相似检测的哈希计算放在主线程等待，照片多时会卡；改为后台分批 + 进度回调。

**P1 — 体验对齐**
5. 还原 Android 的玻璃拟态/卡片堆叠动效（`LiquidGlass` / `CardStack` / `GenieEffect`），用 SwiftUI `material` + `matchedGeometryEffect`。
6. 桌面小组件（WidgetKit）、App Shortcuts、撤销 Snackbar。
7. 设置页补齐：智能排序、隐藏/屏蔽图集、隐私政策、关于。
8. Live Photo / 动图（`MotionPhotoPlayer`）在 iOS 用 `PHLivePhotoView`。

**P2 — 工程化**
9. iOS 单元测试：把 `Algorithms/` 单独建 Test Target，用固定图片验证 dHash 与分组结果和 Android 一致。
10. 若两端长期维护，把 `Models/` + `Algorithms/` 抽成 Kotlin Multiplatform 共享模块（这些代码已经刻意不依赖平台框架）。
11. 图标资源、App Store 截图、隐私清单（PrivacyManifest）。

---

## 六、注意事项

- 本骨架**无法在 Windows 上编译**，必须在 Mac + Xcode 下运行。
- 所有照片处理都在本机，无联网逻辑；Android 版的"检查更新/安装 APK"功能不适用 iOS，已移除。
- `GENERATE_INFOPLIST_FILE = YES` 且指定了 `INFOPLIST_FILE`，Xcode 会合并两者；权限描述以 `Info.plist` 为准。
