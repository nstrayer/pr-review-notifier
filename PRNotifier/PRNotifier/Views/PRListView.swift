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
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }

            if viewModel.activePRs.isEmpty && viewModel.dismissedPRs.isEmpty && viewModel.authoredPRs.isEmpty {
                emptyState
            } else {
                statsHeader
                // Active PRs
                section(title: "Reviews Requested", prs: viewModel.activePRs) { prID in
                    viewModel.dismiss(prID)
                }

                if viewModel.activePRs.isEmpty {
                    Text("No PRs waiting for your review")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                }

                // Dismissed PRs
                if !viewModel.dismissedPRs.isEmpty {
                    dismissedSection
                }

                // Authored PRs
                authoredSections
            }
        }
        .padding(.bottom, 12)
    }

    // MARK: - Stats header

    private var statsHeader: some View {
        HStack(spacing: 4) {
            Text("To review:")
                .foregroundStyle(.secondary)
            Text("\(viewModel.activePRs.count)")
                .fontWeight(.medium)

            Text("|")
                .foregroundStyle(.quaternary)
                .padding(.horizontal, 2)

            Text("Your PRs:")
                .foregroundStyle(.secondary)
            Text("\(viewModel.authoredPRs.count)")
                .fontWeight(.medium)

            if !viewModel.authoredPRs.isEmpty {
                Text("(\(viewModel.authoredReceivedReview.count) reviewed, \(viewModel.authoredAwaitingReview.count) awaiting)")
                    .foregroundStyle(.tertiary)
            }
        }
        .font(.caption)
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.fill.quaternary)
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
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    Text("(\(prs.count))")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)

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

    // MARK: - Authored sections

    @ViewBuilder
    private var authoredSections: some View {
        section(title: "Your PRs - Awaiting Reviews", prs: viewModel.authoredAwaitingReview, showReviewStatus: true)
        section(title: "Your PRs - Reviews Received", prs: viewModel.authoredReceivedReview, showReviewStatus: true)
    }
}
