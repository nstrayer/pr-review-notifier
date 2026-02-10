import Foundation

actor PersistenceManager {
    static let shared = PersistenceManager()

    private let fileURL: URL

    struct CacheData: Codable {
        var pendingPRs: [PR] = []
        var authoredPRs: [PR] = []
        var notifiedPRIDs: Set<Int> = []
        var dismissedPRIDs: Set<Int> = []
        var lastQueryTime: Date?
        var lastCheckHadErrors: Bool = false
        var lastCheckErrors: [CheckError] = []
    }

    private var cache: CacheData

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("PRNotifier", isDirectory: true)

        if !FileManager.default.fileExists(atPath: appDir.path) {
            try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        }

        fileURL = appDir.appendingPathComponent("cache.json")

        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode(CacheData.self, from: data) {
            cache = decoded
        } else {
            cache = CacheData()
        }
    }

    // MARK: - Read

    func getPendingPRs() -> [PR] { cache.pendingPRs }
    func getAuthoredPRs() -> [PR] { cache.authoredPRs }
    func getNotifiedPRIDs() -> Set<Int> { cache.notifiedPRIDs }
    func getDismissedPRIDs() -> Set<Int> { cache.dismissedPRIDs }
    func getLastQueryTime() -> Date? { cache.lastQueryTime }
    func getLastCheckHadErrors() -> Bool { cache.lastCheckHadErrors }
    func getLastCheckErrors() -> [CheckError] { cache.lastCheckErrors }
    func getCache() -> CacheData { cache }

    // MARK: - Write

    func setPendingPRs(_ prs: [PR]) { cache.pendingPRs = prs; save() }
    func setAuthoredPRs(_ prs: [PR]) { cache.authoredPRs = prs; save() }
    func setNotifiedPRIDs(_ ids: Set<Int>) { cache.notifiedPRIDs = ids; save() }
    func setDismissedPRIDs(_ ids: Set<Int>) { cache.dismissedPRIDs = ids; save() }
    func setLastQueryTime(_ date: Date?) { cache.lastQueryTime = date; save() }

    func setLastCheckErrors(_ errors: [CheckError]) {
        cache.lastCheckHadErrors = !errors.isEmpty
        cache.lastCheckErrors = errors
        save()
    }

    func addDismissedPRID(_ id: Int) {
        cache.dismissedPRIDs.insert(id)
        save()
    }

    func removeDismissedPRID(_ id: Int) {
        cache.dismissedPRIDs.remove(id)
        save()
    }

    func addNotifiedPRID(_ id: Int) {
        cache.notifiedPRIDs.insert(id)
        save()
    }

    func update(_ block: (inout CacheData) -> Void) {
        block(&cache)
        save()
    }

    // MARK: - Persistence

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(cache) else { return }

        // Atomic write
        let tempURL = fileURL.deletingLastPathComponent()
            .appendingPathComponent(UUID().uuidString + ".tmp")
        do {
            try data.write(to: tempURL, options: .atomic)
            _ = try FileManager.default.replaceItemAt(fileURL, withItemAt: tempURL)
        } catch {
            // Fallback: direct write
            try? data.write(to: fileURL, options: .atomic)
            try? FileManager.default.removeItem(at: tempURL)
        }
    }
}
