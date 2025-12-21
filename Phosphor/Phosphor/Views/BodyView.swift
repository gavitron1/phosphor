import SwiftUI

struct BodyView: View {
    @ObservedObject var dataManager = DataManager.shared

    @State private var showStats = false
    @State private var showSettings = false
    @State private var currentSide: BodySide = .front

    var body: some View {
        ZStack {
            // Background
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Body image view - use flexible space to maximize image size
                TappableBodyView(
                    gender: dataManager.settings.gender,
                    side: currentSide,
                    highlightColor: dataManager.settings.highlightColor.color,
                    darkMode: dataManager.settings.darkMode,
                    getIntensity: { dataManager.getIntensity(for: $0) },
                    onMuscleGroupTapped: { muscleGroup in
                        dataManager.tapMuscleGroup(muscleGroup)
                        hapticFeedback()
                    }
                )
                .padding(.horizontal, 8)
                .padding(.top, 56)
                .padding(.bottom, 8)

                // Front/Back toggle
                Picker("Side", selection: $currentSide) {
                    ForEach(BodySide.allCases, id: \.self) { side in
                        Text(side.rawValue).tag(side)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 32)
                .padding(.bottom, 16)
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
