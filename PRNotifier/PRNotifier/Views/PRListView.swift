import SwiftUI

enum StatsTab: String, CaseIterable {
    case toReview
    case reviewed
    case awaiting
}

struct PRListView: View {
    @Environment(PRViewModel.self) private var viewModel

    var onNavigateToSettings: (() -> Void)?

    @State private var selectedTab: StatsTab = .toReview
    @State private var showDismissed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Error banner
            if !viewModel.errors.isEmpty {
                ErrorBannerView(onNavigateToSettings: onNavigateToSettings)
            }

            // Last checked
            if let lastCheck = viewModel.lastCheckTime {
                HStack {
                    Spacer()
                    Text("Last checked: \(lastCheck, format: .relative(presentation: .named))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .italic()
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }

            if viewModel.activePRs.isEmpty && viewModel.dismissedPRs.isEmpty && viewModel.authoredPRs.isEmpty {
                emptyState
            } else {
                statsHeader

                switch selectedTab {
                case .toReview:
                    toReviewContent
                case .reviewed:
                    reviewedContent
                case .awaiting:
                    awaitingContent
                }
            }
        }
        .padding(.bottom, 12)
    }

    // MARK: - Stats header

    private var statsHeader: some View {
        HStack(spacing: 8) {
            statCard(
                tab: .toReview,
                count: viewModel.activePRs.count,
                label: "To review",
                color: .blue
            )
            statCard(
                tab: .reviewed,
                count: viewModel.authoredReceivedReview.count,
                label: "Reviewed",
                color: .green
            )
            statCard(
                tab: .awaiting,
                count: viewModel.authoredAwaitingReview.count,
                label: "Awaiting",
                color: .orange
            )
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private func statCard(tab: StatsTab, count: Int, label: String, color: Color) -> some View {
        let isSelected = selectedTab == tab

        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: 2) {
                Text("\(count)")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(isSelected ? color : .secondary)
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(isSelected ? color : Color.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                isSelected ? color.opacity(0.12) : Color.primary.opacity(0.03),
                in: RoundedRectangle(cornerRadius: 8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isSelected ? color.opacity(0.3) : .clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Tab content

    @ViewBuilder
    private var toReviewContent: some View {
        if viewModel.activePRs.isEmpty {
            tabEmptyState("No PRs waiting for your review")
        } else {
            prList(prs: viewModel.activePRs) { prID in
                viewModel.dismiss(prID)
            }
        }

        if !viewModel.dismissedPRs.isEmpty {
            dismissedSection
        }
    }

    @ViewBuilder
    private var reviewedContent: some View {
        if viewModel.authoredReceivedReview.isEmpty {
            tabEmptyState("None of your PRs have been reviewed yet")
        } else {
            prList(prs: viewModel.authoredReceivedReview, showReviewStatus: true)
        }
    }

    @ViewBuilder
    private var awaitingContent: some View {
        if viewModel.authoredAwaitingReview.isEmpty {
            tabEmptyState("All your PRs have received reviews")
        } else {
            prList(prs: viewModel.authoredAwaitingReview, showReviewStatus: true)
        }
    }

    private func tabEmptyState(_ message: String) -> some View {
        Text(message)
            .font(.subheadline)
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
    }

    // MARK: - PR list helper

    @ViewBuilder
    private func prList(
        prs: [PR],
        action: ((Int) -> Void)? = nil,
        isRestore: Bool = false,
        showReviewStatus: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(prs) { pr in
                PRCardView(
                    pr: pr,
                    isDismissed: isRestore,
                    showReviewStatus: showReviewStatus,
                    onDismiss: isRestore ? nil : action.map { a in { a(pr.id) } },
                    onRestore: isRestore ? action.map { a in { a(pr.id) } } : nil
                )
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("No pull requests")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("When you have PRs to review or PRs you've created, they'll appear here.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 16)
    }

    // MARK: - Dismissed section (collapsible)

    private var dismissedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showDismissed.toggle()
                }
            } label: {
                HStack {
                    Text("Dismissed PRs")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    Text("(\(viewModel.dismissedPRs.count))")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                    Spacer()
                    Image(systemName: showDismissed ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.top, 10)

            if showDismissed {
                ForEach(viewModel.dismissedPRs) { pr in
                    PRCardView(
                        pr: pr,
                        isDismissed: true,
                        showReviewStatus: false,
                        onDismiss: nil,
                        onRestore: { viewModel.undismiss(pr.id) }
                    )
                }
            }
        }
    }

}
