import SwiftUI

struct ContentView: View {
    @StateObject private var dataManager = DataManager.shared
    @State private var selectedTab = 0 // Start on Body tab (first)

    var body: some View {
        TabView(selection: $selectedTab) {
            BodyView()
                .tabItem {
                    Image(systemName: "figure.stand")
                }
                .tag(0)

            StatsView()
                .tabItem {
                    Image(systemName: "chart.bar.fill")
                }
                .tag(1)

            CalendarView()
                .tabItem {
                    Image(systemName: "calendar")
                }
                .tag(2)

            SettingsView()
                .tabItem {
                    Image(systemName: "gearshape.fill")
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
