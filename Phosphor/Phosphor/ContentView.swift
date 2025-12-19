import SwiftUI

struct ContentView: View {
    @StateObject private var dataManager = DataManager.shared

    var body: some View {
        TabView {
            BodyView()
                .tabItem {
                    Label("Body", systemImage: "figure.stand")
                }

            StatsView()
                .tabItem {
                    Label("Stats", systemImage: "chart.bar.fill")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
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
