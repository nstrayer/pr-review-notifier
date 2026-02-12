import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(PRViewModel.self) private var viewModel

    // MARK: - Local editing state

    @State private var token = ""
    @State private var username = ""
    @State private var repos: [String] = []
    @State private var newRepo = ""
    @State private var checkInterval = 15
    @State private var autoLaunch = false

    @State private var errors: [String: String] = [:]
    @State private var showDevOptions = false
    @State private var didLoad = false
    @State private var showSaveConfirmation = false
    @State private var showOAuthSheet = false
    @State private var showPATSection = false

    var body: some View {
        Form {
            // Setup banner
            if !settings.isConfigured {
                setupBanner
            }

            // Authentication
            authSection

            // GitHub Username (only for PAT mode)
            if settings.authMethod == .pat {
                usernameSection
            }

            // Repositories
            Section {
                HStack {
                    TextField("owner/repo", text: $newRepo)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { addRepo() }
                        .onChange(of: newRepo) { errors.removeValue(forKey: "repo") }
                    Button("Add") { addRepo() }
                        .disabled(newRepo.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                if let error = errors["repo"] {
                    Text(error).font(.caption).foregroundStyle(.red)
                }
                ForEach(repos, id: \.self) { repo in
                    HStack {
                        Text(repo)
                            .font(.body)
                        Spacer()
                        Button {
                            if let index = repos.firstIndex(of: repo) {
                                repos.remove(at: index)
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            } header: {
                Text("Repositories")
            } footer: {
                Text("Repositories to monitor for pull request review requests.")
            }

            // Check Interval
            Section {
                Stepper(
                    "\(checkInterval) minute\(checkInterval == 1 ? "" : "s")",
                    value: $checkInterval,
                    in: 1...60
                )
                .onChange(of: checkInterval) { errors.removeValue(forKey: "checkInterval") }
                if let error = errors["checkInterval"] {
                    Text(error).font(.caption).foregroundStyle(.red)
                }
            } header: {
                Text("Check Interval")
            } footer: {
                Text("How often to check for new review requests.")
            }

            // Notifications
            Section {
                @Bindable var s = settings
                Toggle("Desktop notifications", isOn: $s.enableNotifications)
            } header: {
                Text("Notifications")
            } footer: {
                Text("Show a macOS notification when new review requests are found.")
            }

            // Auto-launch
            Section {
                Toggle("Launch at login", isOn: $autoLaunch)
                    .onChange(of: autoLaunch) { _, newValue in
                        updateAutoLaunch(enabled: newValue)
                    }
            } header: {
                Text("Auto-launch")
            } footer: {
                Text("Automatically start PR Notifier when you log in to your Mac.")
            }

            // Developer Options
            Section {
                DisclosureGroup("Developer Options", isExpanded: $showDevOptions) {
                    @Bindable var s = settings
                    Toggle("Show sample PRs", isOn: $s.devShowSamplePRs)
                        .onChange(of: settings.devShowSamplePRs) {
                            viewModel.restartPolling()
                        }
                }
            }

            // Save
            Section {
                Button("Save") { save() }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)

                if showSaveConfirmation {
                    HStack {
                        Spacer()
                        Label("Settings saved", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                        Spacer()
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onAppear { loadSettings() }
        .sheet(isPresented: $showOAuthSheet) {
            OAuthLoginView {
                // On success: reload settings and restart polling
                loadSettingsFromSource()
                viewModel.restartPolling()
            }
        }
    }

    // MARK: - Auth Section

    @ViewBuilder
    private var authSection: some View {
        Section {
            switch settings.authMethod {
            case .oauth:
                if !settings.oauthUsername.isEmpty {
                    // Signed in via OAuth
                    HStack {
                        Image(systemName: "person.crop.circle.fill")
                            .foregroundStyle(.green)
                        Text("Signed in as @\(settings.oauthUsername)")
                        Spacer()
                        Button("Sign Out") { signOut() }
                            .foregroundStyle(.red)
                    }
                } else {
                    // Not signed in yet
                    Button("Sign in with GitHub") {
                        showOAuthSheet = true
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                }

                // Advanced PAT option
                DisclosureGroup("Advanced: Use Personal Access Token", isExpanded: $showPATSection) {
                    SecureField("Token", text: $token)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: token) { errors.removeValue(forKey: "token") }
                    if let error = errors["token"] {
                        Text(error).font(.caption).foregroundStyle(.red)
                    }
                    Button("Switch to PAT") {
                        switchToPAT()
                    }
                    .disabled(token.trimmingCharacters(in: .whitespaces).isEmpty)
                }

            case .pat:
                // Using PAT
                HStack {
                    Image(systemName: "key.fill")
                        .foregroundStyle(.secondary)
                    Text("Using Personal Access Token")
                        .foregroundStyle(.secondary)
                }

                SecureField("Token", text: $token)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: token) { errors.removeValue(forKey: "token") }
                if let error = errors["token"] {
                    Text(error).font(.caption).foregroundStyle(.red)
                }

                Button("Switch to GitHub Sign-In") {
                    showOAuthSheet = true
                }
                .font(.callout)
            }
        } header: {
            Text("Authentication")
        } footer: {
            if settings.authMethod == .oauth && settings.oauthUsername.isEmpty {
                Text("Sign in with your GitHub account to authenticate. Your browser will open to complete the process.")
            } else if settings.authMethod == .pat {
                Text("A personal access token used to authenticate with the GitHub API. Generate one at github.com > Settings > Developer settings > Personal access tokens.")
            }
        }
    }

    // MARK: - Username Section

    private var usernameSection: some View {
        Section {
            TextField("Username", text: $username)
                .textFieldStyle(.roundedBorder)
                .onChange(of: username) { errors.removeValue(forKey: "username") }
            if let error = errors["username"] {
                Text(error).font(.caption).foregroundStyle(.red)
            }
        } header: {
            Text("GitHub Username")
        } footer: {
            Text("Your GitHub username. Used to identify pull requests where your review is requested.")
        }
    }

    // MARK: - Setup banner

    private var setupBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
            Text("Sign in with GitHub and add repositories to get started.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(Color.yellow.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.yellow.opacity(0.3), lineWidth: 0.5)
        )
    }

    // MARK: - Load

    private func loadSettings() {
        guard !didLoad else { return }
        didLoad = true
        loadSettingsFromSource()
    }

    private func loadSettingsFromSource() {
        token = KeychainService.getToken() ?? ""
        username = settings.username
        repos = settings.repos
        checkInterval = settings.checkInterval
        autoLaunch = settings.autoLaunch
    }

    // MARK: - Add repo

    private func addRepo() {
        let trimmed = newRepo.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        guard InputValidation.validateRepository(trimmed) else {
            errors["repo"] = "Invalid format. Use owner/repo (e.g. octocat/Hello-World)."
            return
        }

        if repos.contains(trimmed) {
            errors["repo"] = "Repository already added."
            return
        }

        repos.append(trimmed)
        newRepo = ""
    }

    // MARK: - Save

    private func save() {
        errors = [:]

        // Only validate token for PAT mode
        if settings.authMethod == .pat {
            let trimmedToken = token.trimmingCharacters(in: .whitespaces)
            if trimmedToken.isEmpty {
                errors["token"] = "GitHub token is required."
            } else if !InputValidation.validateGitHubToken(trimmedToken) {
                errors["token"] = "Invalid token. Must start with ghp_, gho_, ghs_, or github_pat_ and be 40+ characters."
            }
        }

        // Validate username (only for PAT mode)
        if settings.authMethod == .pat {
            let trimmedUsername = username.trimmingCharacters(in: .whitespaces)
            if trimmedUsername.isEmpty {
                errors["username"] = "GitHub username is required."
            } else if !InputValidation.validateUsername(trimmedUsername) {
                errors["username"] = "Invalid username. Use alphanumeric characters and hyphens only."
            }
        }

        // Validate check interval
        if !InputValidation.validateCheckInterval(checkInterval) {
            errors["checkInterval"] = "Must be between 1 and 1440 minutes."
        }

        guard errors.isEmpty else { return }

        // Write PAT token if in PAT mode
        if settings.authMethod == .pat {
            let trimmedToken = token.trimmingCharacters(in: .whitespaces)
            do {
                if trimmedToken.isEmpty {
                    try KeychainService.deleteToken()
                } else {
                    try KeychainService.setToken(trimmedToken)
                }
            } catch {
                errors["token"] = "Failed to save token: \(error.localizedDescription)"
                return
            }
        }

        // Write settings
        if settings.authMethod == .pat {
            settings.username = username.trimmingCharacters(in: .whitespaces)
        }
        settings.repos = repos
        settings.checkInterval = checkInterval

        // Restart polling to pick up changes
        viewModel.restartPolling()

        // Show confirmation
        showSaveConfirmation = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showSaveConfirmation = false
        }
    }

    // MARK: - Auth Actions

    private func signOut() {
        try? KeychainService.deleteOAuthToken()
        settings.authMethod = .oauth
        settings.oauthUsername = ""
        viewModel.restartPolling()
    }

    private func switchToPAT() {
        let trimmedToken = token.trimmingCharacters(in: .whitespaces)
        guard !trimmedToken.isEmpty else { return }

        guard InputValidation.validateGitHubToken(trimmedToken) else {
            errors["token"] = "Invalid token. Must start with ghp_, gho_, ghs_, or github_pat_ and be 40+ characters."
            return
        }

        do {
            try KeychainService.setToken(trimmedToken)
            // Clear OAuth token
            try? KeychainService.deleteOAuthToken()
            settings.authMethod = .pat
            settings.oauthUsername = ""
            showPATSection = false
        } catch {
            errors["token"] = "Failed to save token: \(error.localizedDescription)"
        }
    }

    // MARK: - Auto-launch

    private func updateAutoLaunch(enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            settings.autoLaunch = enabled
        } catch {
            // Revert toggle on failure
            autoLaunch = !enabled
            print("Failed to update auto-launch: \(error)")
        }
    }
}
