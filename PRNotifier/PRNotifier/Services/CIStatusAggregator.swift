import Foundation

enum CIStatusAggregator {

    static func aggregate(checkRuns: [CheckRunInfo], commitStatuses: [CheckRunInfo]) -> CIInfo {
        var checksByName: [String: CheckRunInfo] = [:]

        for run in checkRuns {
            checksByName[run.name.lowercased()] = run
        }
        for status in commitStatuses {
            let key = status.name.lowercased()
            if checksByName[key] == nil {
                checksByName[key] = status
            }
        }

        let checks = Array(checksByName.values)

        let overallStatus: CIStatus
        if checks.isEmpty {
            overallStatus = .none
        } else if checks.contains(where: { $0.status == .failing }) {
            overallStatus = .failing
        } else if checks.contains(where: { $0.status == .pending }) {
            overallStatus = .pending
        } else {
            overallStatus = .passing
        }

        return CIInfo(checks: checks, overallStatus: overallStatus)
    }
}
