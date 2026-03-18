import SwiftUI

struct CIStatusView: View {
    let ciInfo: CIInfo

    @State private var isExpanded = false

    private var passingCount: Int {
        ciInfo.checks.filter { $0.status == .passing }.count
    }

    private var summaryColor: Color {
        switch ciInfo.overallStatus {
        case .passing: .green
        case .failing: .red
        case .pending: .orange
        case .none: .gray
        }
    }

    private var sortedChecks: [CheckRunInfo] {
        ciInfo.checks.sorted { a, b in
            let order: [CheckRunStatus: Int] = [.failing: 0, .pending: 1, .passing: 2]
            let ao = order[a.status] ?? 3
            let bo = order[b.status] ?? 3
            if ao != bo { return ao < bo }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button {
                withAnimation(.easeInOut(duration: 0.12)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: statusIcon)
                        .font(.caption2)
                        .foregroundStyle(summaryColor)
                    Text("CI: \(passingCount)/\(ciInfo.checks.count) checks passing")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 8))
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(sortedChecks, id: \.name) { check in
                        HStack(spacing: 6) {
                            Image(systemName: checkIcon(for: check.status))
                                .font(.system(size: 9))
                                .foregroundStyle(checkColor(for: check.status))
                                .frame(width: 12)
                            Text(check.name)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            Spacer()
                            Text(check.status.rawValue)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .padding(.leading, 4)
            }
        }
    }

    private var statusIcon: String {
        switch ciInfo.overallStatus {
        case .passing: "checkmark.circle.fill"
        case .failing: "xmark.circle.fill"
        case .pending: "clock.fill"
        case .none: "minus.circle"
        }
    }

    private func checkIcon(for status: CheckRunStatus) -> String {
        switch status {
        case .passing: "checkmark.circle.fill"
        case .failing: "xmark.circle.fill"
        case .pending: "clock.fill"
        }
    }

    private func checkColor(for status: CheckRunStatus) -> Color {
        switch status {
        case .passing: .green
        case .failing: .red
        case .pending: .orange
        }
    }
}
