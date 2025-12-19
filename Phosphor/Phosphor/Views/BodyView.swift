import SwiftUI

struct BodyView: View {
    @ObservedObject var dataManager = DataManager.shared

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    headerView

                    muscleGroupGrid
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Phosphor")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        Task {
                            await dataManager.syncFromCloud()
                        }
                    }) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                    }
                    .disabled(dataManager.isLoading)
                }
            }
            .refreshable {
                await dataManager.syncFromCloud()
            }
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
