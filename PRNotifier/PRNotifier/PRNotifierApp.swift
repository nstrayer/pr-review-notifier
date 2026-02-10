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
            Image("MenuBarIcon")
            Text(viewModel.menuBarTitle)
        }
        .menuBarExtraStyle(.window)
    }
}
