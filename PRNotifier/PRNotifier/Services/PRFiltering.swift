import Foundation

func partitionPRs(_ prs: [PR], dismissedIDs: Set<Int>) -> (active: [PR], dismissed: [PR]) {
    let active = prs.filter { !dismissedIDs.contains($0.id) }
    let dismissed = prs.filter { dismissedIDs.contains($0.id) }
    return (active, dismissed)
}

func cleanStaleDismissedIDs(validIDs: Set<Int>, current: Set<Int>) -> Set<Int> {
    current.intersection(validIDs)
}
