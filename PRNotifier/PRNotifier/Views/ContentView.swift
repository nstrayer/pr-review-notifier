import SwiftUI

struct ContentView: View {
    @Environment(PRViewModel.self) private var viewModel

    var onOpenSettings: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                PRListView(onNavigateToSettings: onOpenSettings)
            }

            footer
        }
        .frame(width: 400, height: 500)
        .task {
            await viewModel.start()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("PR Notifier")
                .font(.headline)
            Spacer()
            Button {
                onOpenSettings()
            } label: {
                Image(systemName: "gearshape")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.bar)
    }

    private var footer: some View {
        VStack(spacing: 0) {
            Divider()
            Button {
                Task { await viewModel.checkNow() }
            } label: {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.small)
                        .opacity(viewModel.isLoading ? 1 : 0)
                    Text(viewModel.isLoading ? "Checking..." : "Check Now")
                }
                .frame(maxWidth: .infinity)
            }
            .disabled(viewModel.isLoading)
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.bar)
        }
    }
}
