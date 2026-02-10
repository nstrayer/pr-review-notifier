import SwiftUI

struct ErrorBannerView: View {
    @Environment(PRViewModel.self) private var viewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
                    .font(.body)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Error checking pull requests")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(Color(red: 0.6, green: 0.1, blue: 0.1))

                    ForEach(Array(viewModel.errors.enumerated()), id: \.offset) { _, error in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 0) {
                                if let repoName = error.repoName {
                                    Text("\(repoName): ")
                                        .fontWeight(.medium)
                                }
                                Text(error.message)
                            }
                            .font(.caption)
                            .foregroundStyle(Color(red: 0.5, green: 0.1, blue: 0.1))

                            if let details = error.details {
                                Text(details)
                                    .font(.caption2)
                                    .foregroundStyle(Color(red: 0.55, green: 0.15, blue: 0.15))
                            }
                        }
                        .padding(.bottom, 4)
                    }

                    if viewModel.errors.contains(where: { $0.type == .auth }) {
                        // Placeholder -- settings tab switch will be wired in Phase 6
                        Text("Go to Settings")
                            .font(.caption)
                            .foregroundStyle(.red)
                            .underline()
                    }
                }
            }
        }
        .padding(12)
        .background(Color.red.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.red.opacity(0.2), lineWidth: 0.5)
        )
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }
}
