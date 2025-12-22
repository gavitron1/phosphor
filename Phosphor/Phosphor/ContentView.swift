import SwiftUI

struct ContentView: View {
    @StateObject private var dataManager = DataManager.shared
    @State private var selectedTab = 1 // Start on Body tab (middle)

    var body: some View {
        TabView(selection: $selectedTab) {
            StatsView()
                .tabItem {
                    Label("Stats", systemImage: "chart.bar.fill")
                }
                .tag(0)

            BodyView()
                .tabItem {
                    Label("Body", systemImage: "figure.stand")
                }
                .tag(1)

            CalendarView()
                .tabItem {
                    Label("Calendar", systemImage: "calendar")
                }
                .tag(2)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(3)
        }
        .tint(dataManager.settings.highlightColor.color)
        .preferredColorScheme(dataManager.settings.darkMode ? .dark : .light)
        .onAppear {
            Task {
                await dataManager.syncFromCloud()
            }
        }
    }
}

#Preview {
    ContentView()
}
