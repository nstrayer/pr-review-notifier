import Foundation

enum CheckRunStatus: String, Codable, Equatable {
    case passing, failing, pending
}

enum CIStatus: String, Codable, Equatable {
    case passing, failing, pending, none
}

struct CheckRunInfo: Codable, Equatable {
    let name: String
    let status: CheckRunStatus
}

struct CIInfo: Codable, Equatable {
    let checks: [CheckRunInfo]
    let overallStatus: CIStatus
}
