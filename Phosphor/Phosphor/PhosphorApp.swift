import SwiftUI

@main
struct PhosphorApp: App {
    @ObservedObject private var dataManager = DataManager.shared

    private var colorScheme: ColorScheme? {
        switch dataManager.settings.appearanceMode {
        case .light:
            return .light
        case .dark:
            return .dark
        case .system:
            return nil
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(colorScheme)
        }
    }
}
