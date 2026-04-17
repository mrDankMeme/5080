import UIKit
import OSLog
import CryptoKit

final class ImageCacheManager: @unchecked Sendable {
    static let shared = ImageCacheManager()
    
    private let memoryCache = NSCache<NSString, UIImage>()
    private let session: URLSession
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Pictory5046", category: "ImageCache")
    
    private init() {
        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        cacheDirectory = caches.appendingPathComponent("ImageCache", isDirectory: true)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        session = URLSession(configuration: config)
        
        memoryCache.countLimit = 300
        memoryCache.totalCostLimit = 150 * 1024 * 1024
    }
    
    func image(for urlString: String) async -> UIImage? {
        let key = cacheKey(for: urlString)
        
        if let cached = memoryCache.object(forKey: key as NSString) {
            return cached
        }
        
        if let diskImage = loadFromDisk(key: key) {
            memoryCache.setObject(diskImage, forKey: key as NSString)
            return diskImage
        }
        
        guard let url = URL(string: urlString) else {
            logger.error("ImageCache: Invalid URL — \(urlString)")
            return nil
        }
        
        do {
            let (data, _) = try await session.data(from: url)
            guard let image = UIImage(data: data) else {
                logger.error("ImageCache: Cannot decode image — \(urlString)")
                return nil
            }
            
            memoryCache.setObject(image, forKey: key as NSString, cost: data.count)
            saveToDisk(data: data, key: key)
            
            return image
        } catch {
            if !Task.isCancelled {
                logger.error("ImageCache: Download failed — \(error.localizedDescription)")
            }
            return nil
        }
    }
    
    func clearCache() {
        memoryCache.removeAllObjects()
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    func diskCacheSizeInBytes() -> Int64 {
        directorySize(at: cacheDirectory)
    }
    
    private func cacheKey(for urlString: String) -> String {
        let data = Data(urlString.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    private func fileURL(for key: String) -> URL {
        cacheDirectory.appendingPathComponent(key)
    }
    
    private func loadFromDisk(key: String) -> UIImage? {
        let url = fileURL(for: key)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }
    
    private func saveToDisk(data: Data, key: String) {
        let url = fileURL(for: key)
        try? data.write(to: url, options: .atomic)
    }
    
    private func directorySize(at url: URL) -> Int64 {
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }
        
        var totalSize: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard
                let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
                values.isRegularFile == true,
                let fileSize = values.fileSize
            else {
                continue
            }
            totalSize += Int64(fileSize)
        }
        
        return totalSize
    }
}
