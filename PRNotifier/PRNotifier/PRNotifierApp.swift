import SwiftUI

@main
struct PRNotifierApp: App {
    @State private var viewModel = PRViewModel(settings: AppSettings())

    var body: some Scene {
        MenuBarExtra {
            ContentView()
                .environment(viewModel)
                .environment(viewModel.settings)
        } label: {
            Label {
                Text(viewModel.menuBarTitle)
            } icon: {
                Image("MenuBarIcon")
            }
        }
        .menuBarExtraStyle(.window)
    }
}
