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

            CalendarView()
                .tabItem {
                    Image(systemName: "calendar")
                }
                .tag(1)

            SettingsView()
                .tabItem {
                    Image(systemName: "gearshape.fill")
                }
                .tag(2)
        }
        .tint(dataManager.settings.highlightColor.color)
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
