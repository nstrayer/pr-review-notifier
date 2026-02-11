import SwiftUI

struct PRListView: View {
    @Environment(PRViewModel.self) private var viewModel

    var onNavigateToSettings: (() -> Void)?

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
                .padding(.horizontal, 12)
                .padding(.top, 8)
            }

            if viewModel.activePRs.isEmpty && viewModel.dismissedPRs.isEmpty && viewModel.authoredPRs.isEmpty {
                emptyState
            } else {
                // Active PRs
                section(title: "Reviews Requested", prs: viewModel.activePRs) { prID in
                    viewModel.dismiss(prID)
                }

                if viewModel.activePRs.isEmpty {
                    Text("No PRs waiting for your review")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }

                // Dismissed PRs
                if !viewModel.dismissedPRs.isEmpty {
                    dismissedSection
                }

                // Authored PRs
                authoredSections
            }
        }
        .padding(.bottom, 8)
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
        .padding(.vertical, 32)
        .padding(.horizontal, 16)
    }

    // MARK: - Section helper

    @ViewBuilder
    private func section(
        title: String,
        prs: [PR],
        action: ((Int) -> Void)? = nil,
        isRestore: Bool = false,
        showReviewStatus: Bool = false
    ) -> some View {
        if !prs.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    Text("(\(prs.count))")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)

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
        }
    }

    // MARK: - Dismissed section (collapsible)

    private var dismissedSection: some View {
        VStack(alignment: .leading, spacing: 6) {
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
            .padding(.horizontal, 12)
            .padding(.top, 8)

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

    // MARK: - Authored sections

    @ViewBuilder
    private var authoredSections: some View {
        let awaitingReviews = viewModel.authoredPRs.filter { pr in
            pr.reviews == nil || pr.reviews!.isEmpty || pr.reviews!.allSatisfy { $0.state == .pending }
        }
        let receivedReviews = viewModel.authoredPRs.filter { pr in
            guard let reviews = pr.reviews else { return false }
            return reviews.contains { $0.state != .pending }
        }

        section(title: "Your PRs - Awaiting Reviews", prs: awaitingReviews, showReviewStatus: true)
        section(title: "Your PRs - Reviews Received", prs: receivedReviews, showReviewStatus: true)
    }
}
