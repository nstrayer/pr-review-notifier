import SwiftUI

struct ReviewBadgeView: View {
    let review: ReviewInfo

    private var displayName: String {
        review.reviewerName ?? review.reviewerLogin
    }

    private var icon: String {
        switch review.state {
        case .approved: "checkmark.circle.fill"
        case .changesRequested: "xmark.circle.fill"
        case .pending: "clock.fill"
        case .commented: "text.bubble.fill"
        }
    }

    private var badgeColor: Color {
        switch review.state {
        case .approved: .green
        case .changesRequested: .red
        case .pending: .yellow
        case .commented: .gray
        }
    }

    private var foregroundColor: Color {
        switch review.state {
        case .approved: Color(red: 0.13, green: 0.53, blue: 0.13)
        case .changesRequested: Color(red: 0.6, green: 0.1, blue: 0.1)
        case .pending: Color(red: 0.55, green: 0.45, blue: 0.0)
        case .commented: Color(red: 0.3, green: 0.3, blue: 0.3)
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(displayName)
                .font(.caption2)
                .fontWeight(.medium)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(badgeColor.opacity(0.15))
        .foregroundStyle(foregroundColor)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .strokeBorder(badgeColor.opacity(0.3), lineWidth: 0.5)
        )
        .help("\(displayName) - \(review.state.rawValue.replacingOccurrences(of: "_", with: " "))")
    }
}
