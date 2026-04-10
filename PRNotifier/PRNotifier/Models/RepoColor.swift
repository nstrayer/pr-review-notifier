import SwiftUI

enum RepoColor: String, Codable, CaseIterable {
    case blue, green, orange, red, purple, pink, teal, yellow

    var swiftUIColor: Color {
        switch self {
        case .blue: Color(red: 0.0, green: 0.478, blue: 1.0)
        case .green: Color(red: 0.204, green: 0.780, blue: 0.349)
        case .orange: Color(red: 1.0, green: 0.584, blue: 0.0)
        case .red: Color(red: 1.0, green: 0.231, blue: 0.188)
        case .purple: Color(red: 0.686, green: 0.322, blue: 0.871)
        case .pink: Color(red: 1.0, green: 0.176, blue: 0.333)
        case .teal: Color(red: 0.353, green: 0.784, blue: 0.980)
        case .yellow: Color(red: 1.0, green: 0.8, blue: 0.0)
        }
    }
}
