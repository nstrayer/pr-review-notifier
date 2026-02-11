import SwiftUI

struct PRCardView: View {
    let pr: PR
    var isDismissed: Bool = false
    var showReviewStatus: Bool = false
    var onDismiss: (() -> Void)?
    var onRestore: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title
            Button {
                openPR()
            } label: {
                Text(pr.title)
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundStyle(isDismissed ? .secondary : .primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }

            // Repo badge + PR number
            HStack(spacing: 6) {
                Text(pr.repo)
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(isDismissed ? Color.gray.opacity(0.1) : Color.accentColor.opacity(0.1))
                    .foregroundStyle(isDismissed ? Color.secondary : Color.accentColor)
                    .clipShape(Capsule())

                Text("#\(pr.number)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if !showReviewStatus, let author = pr.authorLogin {
                    Text("by \(author)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            // Review badges
            if showReviewStatus, let reviews = pr.reviews {
                if reviews.isEmpty {
                    Text("No reviews yet")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .italic()
                } else {
                    FlowLayout(spacing: 6) {
                        ForEach(reviews, id: \.reviewerLogin) { review in
                            ReviewBadgeView(review: review)
                        }
                    }
                }
            }

            // Action buttons
            HStack(spacing: 8) {
                Button {
                    openPR()
                } label: {
                    Text("View on GitHub")
                        .font(.caption)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                if let onRestore {
                    Button {
                        onRestore()
                    } label: {
                        Text("Restore")
                            .font(.caption)
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.green)
                    .controlSize(.small)
                } else if let onDismiss {
                    Button {
                        onDismiss()
                    } label: {
                        Text("Dismiss")
                            .font(.caption)
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .padding(12)
        .background(isDismissed ? Color.gray.opacity(0.04) : Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
        .padding(.horizontal, 12)
    }

    private func openPR() {
        guard InputValidation.validateGitHubURL(pr.htmlURL),
              let url = URL(string: pr.htmlURL) else { return }
        NSWorkspace.shared.open(url)
    }
}

// MARK: - FlowLayout

struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var height: CGFloat = 0
        for (i, row) in rows.enumerated() {
            let rowHeight = row.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
            height += rowHeight
            if i < rows.count - 1 { height += spacing }
        }
        return CGSize(width: proposal.width ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var y = bounds.minY
        for row in rows {
            let rowHeight = row.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
            var x = bounds.minX
            for subview in row {
                let size = subview.sizeThatFits(.unspecified)
                subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += rowHeight + spacing
        }
    }

    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [[LayoutSubview]] {
        let maxWidth = proposal.width ?? .infinity
        var rows: [[LayoutSubview]] = [[]]
        var currentWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentWidth + size.width > maxWidth && !rows[rows.count - 1].isEmpty {
                rows.append([])
                currentWidth = 0
            }
            rows[rows.count - 1].append(subview)
            currentWidth += size.width + spacing
        }
        return rows
    }
}
