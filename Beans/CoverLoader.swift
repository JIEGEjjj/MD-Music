import UIKit
import ImageIO

/// 全局共享封面加载器：解码后 UIImage 内存缓存 + 磁盘 URLCache + 单飞请求去重。
/// 列表封面、锁屏 artwork、播放页模糊背景、主色提取共用同一份结果，
/// 避免同一封面 URL 被多处各自下载和解码（切一首歌此前最多触发 4 次重复请求）。
final class CoverLoader {
    static let shared = CoverLoader()

    /// 解码上限（最长边，像素）。首页首帧会并发解码 30+ 张封面，
    /// 个别超大原图直接全尺寸解码会造成明显卡顿；1024 覆盖 340pt@3x，视觉无损。
    private static let maxDecodePixel: CGFloat = 1024

    private let cache = NSCache<NSURL, UIImage>()
    private let session: URLSession
    private let lock = NSLock()
    private var inFlight: [URL: Task<UIImage?, Never>] = [:]

    private init() {
        let config = URLSessionConfiguration.default
        // 磁盘缓存让冷启动后滚动列表仍可复用已下载封面；URLCache 自动处理 HTTP 缓存协商
        config.urlCache = URLCache(memoryCapacity: 10 * 1024 * 1024, diskCapacity: 120 * 1024 * 1024)
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.timeoutIntervalForRequest = 15
        session = URLSession(configuration: config)
        cache.countLimit = 400
        cache.totalCostLimit = 96 * 1024 * 1024
    }

    func cachedImage(for url: URL) -> UIImage? {
        cache.object(forKey: url as NSURL)
    }

    /// ImageIO 缩略图解码：按最长边上限降采样，避免超大图全尺寸解码
    private static func decodeImage(from data: Data) -> UIImage? {
        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDecodePixel,
        ] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options) else {
            return UIImage(data: data)
        }
        return UIImage(cgImage: cgImage)
    }

    /// 异步获取封面：命中内存缓存零开销；并发请求同一 URL 自动合并为一次下载
    func image(for url: URL) async -> UIImage? {
        if let hit = cache.object(forKey: url as NSURL) { return hit }
        lock.lock()
        let running = inFlight[url]
        let task: Task<UIImage?, Never>
        if let running {
            task = running
        } else {
            task = Task<UIImage?, Never> { [session, cache] in
                guard let (data, response) = try? await session.data(from: url) else { return nil }
                guard let image = Self.decodeImage(from: data) else { return nil }
                if (200..<300).contains((response as? HTTPURLResponse)?.statusCode ?? 200) {
                    cache.setObject(image, forKey: url as NSURL, cost: Int(image.size.width * image.size.height * 4))
                }
                return image
            }
            inFlight[url] = task
        }
        lock.unlock()
        let image = await task.value
        lock.lock()
        if inFlight[url] == task { inFlight[url] = nil }
        lock.unlock()
        return image
    }
}
