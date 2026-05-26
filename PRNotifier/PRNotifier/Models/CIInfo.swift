import Foundation

enum CheckRunStatus: String, Equatable {
    case passing, failing, pending
}

extension CheckRunStatus: Codable {
    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        self = CheckRunStatus(rawValue: value) ?? .pending
    }
}

enum CIStatus: String, Equatable {
    case passing, failing, pending, none
}

extension CIStatus: Codable {
    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        self = CIStatus(rawValue: value) ?? .none
    }
}

struct CheckRunInfo: Codable, Equatable {
    let name: String
    let status: CheckRunStatus
}

struct CIInfo: Codable, Equatable {
    let checks: [CheckRunInfo]
    let overallStatus: CIStatus

    var sortedChecks: [CheckRunInfo] {
        checks.sorted { a, b in
            let order: [CheckRunStatus: Int] = [.failing: 0, .pending: 1, .passing: 2]
            let ao = order[a.status] ?? 3
            let bo = order[b.status] ?? 3
            if ao != bo { return ao < bo }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
    }
}
