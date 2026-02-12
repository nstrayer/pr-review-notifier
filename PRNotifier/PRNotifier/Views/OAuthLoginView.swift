import SwiftUI

struct OAuthLoginView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    var onSuccess: () -> Void = {}

    @State private var state: FlowState = .loading
    @State private var flowTask: Task<Void, Never>?
    @State private var currentDeviceCode: DeviceCodeResponse?

    private enum FlowState {
        case loading
        case codeReady(userCode: String, verificationURI: String)
        case waiting(userCode: String)
        case success(username: String)
        case error(String)
    }

    var body: some View {
        VStack(spacing: 16) {
            switch state {
            case .loading:
                loadingView

            case .codeReady(let userCode, _):
                codeReadyView(userCode: userCode)

            case .waiting(let userCode):
                waitingView(userCode: userCode)

            case .success(let username):
                successView(username: username)

            case .error(let message):
                errorView(message: message)
            }
        }
        .padding(24)
        .frame(width: 360)
        .onAppear { startFlow() }
        .onDisappear { flowTask?.cancel() }
    }

    // MARK: - State Views

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Requesting authorization code...")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private func codeReadyView(userCode: String) -> some View {
        VStack(spacing: 16) {
            Text("Sign in with GitHub")
                .font(.headline)

            Text("Enter this code on GitHub:")
                .font(.callout)
                .foregroundStyle(.secondary)

            Text(userCode)
                .font(.system(size: 28, weight: .bold, design: .monospaced))
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.secondary.opacity(0.3), lineWidth: 0.5)
                )

            Button("Copy Code & Open GitHub") {
                copyAndOpen()
            }
            .buttonStyle(.borderedProminent)

            Button("Cancel") {
                flowTask?.cancel()
                dismiss()
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
    }

    private func waitingView(userCode: String) -> some View {
        VStack(spacing: 16) {
            Text("Sign in with GitHub")
                .font(.headline)

            Text(userCode)
                .font(.system(size: 28, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("Waiting for authorization...")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Button("Cancel") {
                flowTask?.cancel()
                dismiss()
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
    }

    private func successView(username: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 36))
                .foregroundStyle(.green)

            Text("Signed in as @\(username)")
                .font(.headline)
        }
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 36))
                .foregroundStyle(.yellow)

            Text("Sign-in failed")
                .font(.headline)

            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                Button("Try Again") {
                    startFlow()
                }
                .buttonStyle(.borderedProminent)

                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Flow Logic

    private func startFlow() {
        flowTask?.cancel()
        state = .loading
        currentDeviceCode = nil

        flowTask = Task {
            do {
                let codeResponse = try await DeviceFlowService.requestDeviceCode()

                if Task.isCancelled { return }
                currentDeviceCode = codeResponse
                state = .codeReady(
                    userCode: codeResponse.userCode,
                    verificationURI: codeResponse.verificationURI
                )
            } catch {
                if Task.isCancelled { return }
                state = .error(error.localizedDescription)
            }
        }
    }

    private func copyAndOpen() {
        guard case .codeReady(let userCode, let verificationURI) = state,
              let deviceCode = currentDeviceCode else { return }

        // Copy code to clipboard
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(userCode, forType: .string)

        // Open verification URI in browser
        if let url = URL(string: verificationURI) {
            NSWorkspace.shared.open(url)
        }

        // Begin polling with the existing device code
        state = .waiting(userCode: userCode)
        flowTask?.cancel()
        flowTask = Task {
            do {
                let token = try await DeviceFlowService.pollForToken(
                    deviceCode: deviceCode.deviceCode,
                    interval: deviceCode.interval
                )

                if Task.isCancelled { return }

                // Store the token
                try KeychainService.setOAuthToken(token)

                // Fetch username
                let username = try await DeviceFlowService.fetchUsername(token: token)

                if Task.isCancelled { return }

                // Update settings
                await MainActor.run {
                    settings.authMethod = .oauth
                    settings.oauthUsername = username
                    settings.username = username
                    state = .success(username: username)
                }

                // Auto-dismiss after a short delay
                try? await Task.sleep(for: .seconds(1.5))
                if Task.isCancelled { return }
                await MainActor.run {
                    onSuccess()
                    dismiss()
                }
            } catch {
                if Task.isCancelled { return }
                await MainActor.run {
                    state = .error(error.localizedDescription)
                }
            }
        }
    }
}
