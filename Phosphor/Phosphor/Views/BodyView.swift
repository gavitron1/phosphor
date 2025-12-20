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
                    GlassCircleButton(
                        systemName: "chart.bar.fill",
                        color: dataManager.settings.highlightColor.color,
                        action: { showStats = true }
                    )

                    Spacer()

                    // Settings button (top right)
                    GlassCircleButton(
                        systemName: "gearshape.fill",
                        color: dataManager.settings.highlightColor.color,
                        action: { showSettings = true }
                    )
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

// MARK: - Glass Circle Button

struct GlassCircleButton: View {
    let systemName: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 44, height: 44)
        }
        .modifier(GlassEffectModifier())
    }
}

struct GlassEffectModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .background(.regularMaterial, in: Circle())
                .glassEffect(.regular.interactive())
        } else {
            content
                .background(
                    Circle()
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
                )
        }
    }
}

#Preview {
    BodyView()
}
