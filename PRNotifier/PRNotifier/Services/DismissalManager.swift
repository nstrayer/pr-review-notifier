import Foundation

struct DismissalManager {
    private let persistence = PersistenceManager.shared

    func dismissedIDs() async -> Set<Int> {
        await persistence.getDismissedPRIDs()
    }

    func dismiss(_ id: Int, pendingPRs: [PR]) async {
        await persistence.update { cache in
            cache.dismissedPRIDs.insert(id)
            cache.pendingPRs = pendingPRs
        }
    }

    func restore(_ id: Int, pendingPRs: [PR]) async {
        await persistence.update { cache in
            cache.dismissedPRIDs.remove(id)
            cache.pendingPRs = pendingPRs
        }
    }

    func filterActive(from prs: [PR], dismissed: Set<Int>) -> (active: [PR], dismissed: [PR]) {
        let active = prs.filter { !dismissed.contains($0.id) }
        let dismissedPRs = prs.filter { dismissed.contains($0.id) }
        return (active, dismissedPRs)
    }

    func cleanStale(validIDs: Set<Int>, current: Set<Int>) -> Set<Int> {
        current.intersection(validIDs)
    }
}
