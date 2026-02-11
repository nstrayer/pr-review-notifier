import SwiftUI

struct ContentView: View {
    @Environment(PRViewModel.self) private var viewModel
    @Environment(AppSettings.self) private var settings

    enum Tab: String, CaseIterable {
        case prs = "Pull Requests"
        case settings = "Settings"
    }

    @State private var selectedTab: Tab = .prs

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            // Tab bar
            tabBar

            // Content
            switch selectedTab {
            case .prs:
                ScrollView {
                    PRListView(onNavigateToSettings: { selectedTab = .settings })
                }
            case .settings:
                SettingsView()
            }
        }
        .frame(width: 400, height: 500)
        .task {
            await viewModel.start()
        }
        .onChange(of: settings.isConfigured) {
            if !settings.isConfigured {
                selectedTab = .settings
            }
        }
        .onAppear {
            if !settings.isConfigured && !settings.devShowSamplePRs {
                selectedTab = .settings
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("PR Notifier")
                .font(.headline)

            Spacer()

            if selectedTab == .prs {
                Button {
                    Task { await viewModel.checkNow() }
                } label: {
                    Text(viewModel.isLoading ? "Checking..." : "Check Now")
                }
                .disabled(viewModel.isLoading)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.bar)
    }

    // MARK: - Tab bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.self) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    VStack(spacing: 4) {
                        HStack(spacing: 4) {
                            Text(tab.rawValue)
                                .font(.subheadline)
                                .fontWeight(selectedTab == tab ? .semibold : .regular)
                            if tab == .prs && !viewModel.activePRs.isEmpty {
                                Text("(\(viewModel.activePRs.count))")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .foregroundStyle(selectedTab == tab ? .primary : .secondary)

                        Rectangle()
                            .fill(selectedTab == tab ? Color.accentColor : .clear)
                            .frame(height: 2)
                    }
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 12)
        .background(.bar)
    }
}
