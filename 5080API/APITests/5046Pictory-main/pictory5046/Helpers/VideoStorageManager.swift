import Foundation

enum VideoStorageManager {
    private static let directoryName = "GeneratedVideos"
    
    static func saveVideo(data: Data, jobId: String) throws -> URL {
        let folder = try ensureDirectory()
        let safeJobId = sanitizedFileComponent(jobId)
        let fileURL = folder.appendingPathComponent("\(safeJobId).mp4")
        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }
    
    static func removeVideoIfExists(at path: String?) {
        guard let path, !path.isEmpty else { return }
        let url = URL(fileURLWithPath: path)
        try? FileManager.default.removeItem(at: url)
    }
    
    static func clearAllVideos() {
        guard let folder = directoryURLIfExists() else { return }
        try? FileManager.default.removeItem(at: folder)
    }
    
    static func totalStorageSizeInBytes() -> Int64 {
        guard let folder = directoryURLIfExists() else { return 0 }
        
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: folder,
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
    
    private static func ensureDirectory() throws -> URL {
        let fm = FileManager.default
        let caches = fm.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let folder = caches.appendingPathComponent(directoryName, isDirectory: true)
        if !fm.fileExists(atPath: folder.path) {
            try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        return folder
    }
    
    private static func sanitizedFileComponent(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let filtered = value.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" }
        let result = String(filtered)
        return result.isEmpty ? UUID().uuidString : result
    }
    
    private static func directoryURLIfExists() -> URL? {
        let fileManager = FileManager.default
        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let folder = caches.appendingPathComponent(directoryName, isDirectory: true)
        guard fileManager.fileExists(atPath: folder.path) else { return nil }
        return folder
    }
}
