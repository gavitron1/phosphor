import SwiftUI

struct ContentView: View {
    @StateObject private var dataManager = DataManager.shared

    var body: some View {
        BodyView()
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
