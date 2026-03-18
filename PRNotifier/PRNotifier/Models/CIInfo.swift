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
}
