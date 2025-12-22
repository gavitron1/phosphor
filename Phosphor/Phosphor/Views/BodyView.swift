import SwiftUI

struct BodyView: View {
    @ObservedObject var dataManager = DataManager.shared

    @State private var showStats = false
    @State private var showSettings = false
    @State private var currentSide: BodySide = .front
    @State private var daysAgo: Double = 0 // 0 = today, 10 = 10 days ago

    private var selectedDate: Date {
        Calendar.current.date(byAdding: .day, value: -Int(daysAgo), to: Date()) ?? Date()
    }

    private var endOfDayDate: Date {
        // Get end of the selected day (23:59:59)
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: selectedDate)
        return calendar.date(byAdding: .second, value: 86399, to: startOfDay) ?? selectedDate
    }

    private var dateText: String {
        if daysAgo == 0 {
            return "Today"
        } else if daysAgo == 1 {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: selectedDate)
        }
    }

    private var isViewingHistory: Bool {
        daysAgo > 0
    }

    var body: some View {
        ZStack {
            // Background
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Body image view - fills safe area
                TappableBodyView(
                    gender: dataManager.settings.gender,
                    side: currentSide,
                    highlightColor: dataManager.settings.highlightColor.color,
                    darkMode: dataManager.settings.darkMode,
                    getIntensity: { muscleGroup in
                        if isViewingHistory {
                            return dataManager.getIntensity(for: muscleGroup, asOf: endOfDayDate)
                        } else {
                            return dataManager.getIntensity(for: muscleGroup)
                        }
                    },
                    onMuscleGroupTapped: { muscleGroup in
                        // Only allow tapping when viewing today
                        if !isViewingHistory {
                            dataManager.tapMuscleGroup(muscleGroup)
                            hapticFeedback()
                        }
                    }
                )
                .allowsHitTesting(!isViewingHistory)
            }

            // Top navigation with date
            VStack {
                HStack {
                    // Stats button (top left)
                    GlassCircleButton(
                        systemName: "chart.bar.fill",
                        color: dataManager.settings.highlightColor.color,
                        action: { showStats = true }
                    )

                    Spacer()

                    // Date display (center)
                    Text(dateText)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(isViewingHistory ? dataManager.settings.highlightColor.color : .primary)

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

                // Bottom controls
                HStack(spacing: 12) {
                    // History slider
                    Slider(
                        value: $daysAgo,
                        in: 0...10,
                        step: 1
                    )
                    .tint(dataManager.settings.highlightColor.color)

                    // Swap front/back button
                    GlassCircleButton(
                        systemName: "arrow.left.arrow.right",
                        color: dataManager.settings.highlightColor.color,
                        action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                currentSide = currentSide == .front ? .back : .front
                            }
                        }
                    )
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
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
