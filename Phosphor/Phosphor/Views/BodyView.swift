import SwiftUI

struct BodyView: View {
    @ObservedObject var dataManager = DataManager.shared

    @State private var showStats = false
    @State private var showSettings = false

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 20) {
                    headerView

                    muscleGroupGrid
                }
                .padding()
                .padding(.top, 50)
            }
            .background(Color(.systemGroupedBackground))
            .refreshable {
                await dataManager.syncFromCloud()
            }

            // Top navigation buttons
            VStack {
                HStack {
                    // Stats button (top left)
                    Button(action: { showStats = true }) {
                        Image(systemName: "chart.bar.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(dataManager.settings.highlightColor.color)
                            .frame(width: 44, height: 44)
                    }
                    .background(.regularMaterial, in: Circle())
                    .glassEffect(.regular.interactive())

                    Spacer()

                    // Settings button (top right)
                    Button(action: { showSettings = true }) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(dataManager.settings.highlightColor.color)
                            .frame(width: 44, height: 44)
                    }
                    .background(.regularMaterial, in: Circle())
                    .glassEffect(.regular.interactive())
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                Spacer()
            }
        }
        .fullScreenCover(isPresented: $showStats) {
            StatsView()
        }
        .fullScreenCover(isPresented: $showSettings) {
            SettingsView()
        }
    }

    private var headerView: some View {
        VStack(spacing: 8) {
            Text("Tap a muscle group after your workout")
                .font(.subheadline)
                .foregroundColor(.secondary)

            if let error = dataManager.syncError {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }

    private var muscleGroupGrid: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(MuscleGroup.allCases) { group in
                MuscleGroupButton(
                    muscleGroup: group,
                    intensity: dataManager.getIntensity(for: group),
                    highlightColor: dataManager.settings.highlightColor.color,
                    onTap: {
                        dataManager.tapMuscleGroup(group)
                        hapticFeedback()
                    }
                )
                .frame(height: 100)
            }
        }
    }

    private func hapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
}

#Preview {
    BodyView()
}
