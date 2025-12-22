import SwiftUI

struct BodyView: View {
    @ObservedObject var dataManager = DataManager.shared
    @ObservedObject var notificationManager = NotificationManager.shared

    @State private var currentSide: BodySide = .front
    @State private var daysOffset: Double = 0 // -7 = 7 days ago, 0 = today, +7 = 7 days in future

    private var selectedDate: Date {
        Calendar.current.date(byAdding: .day, value: Int(daysOffset), to: Date()) ?? Date()
    }

    private var endOfDayDate: Date {
        // Get end of the selected day (23:59:59)
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: selectedDate)
        return calendar.date(byAdding: .second, value: 86399, to: startOfDay) ?? selectedDate
    }

    private var dateText: String {
        if daysOffset == 0 {
            return "Today"
        } else if daysOffset == -1 {
            return "Yesterday"
        } else if daysOffset == 1 {
            return "Tomorrow"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: selectedDate)
        }
    }

    private var isViewingHistory: Bool {
        daysOffset != 0
    }

    private var hasDataForSelectedDate: Bool {
        // Check if any muscle group has intensity > 0 for the selected date
        for group in MuscleGroup.allCases {
            if dataManager.getIntensity(for: group, asOf: endOfDayDate) > 0 {
                return true
            }
        }
        return false
    }

    var body: some View {
        ZStack {
            // Background
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            if daysOffset < 0 && !hasDataForSelectedDate {
                // No data message (only for past dates)
                VStack(spacing: 8) {
                    Text("No Data")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                }
            } else {
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
                            let wasRecorded = dataManager.tapMuscleGroup(muscleGroup)
                            if wasRecorded {
                                hapticFeedbackTap()
                                // Schedule cooldown notifications
                                notificationManager.scheduleCooldownNotifications(
                                    muscleData: dataManager.muscleGroupData,
                                    cooldownDays: dataManager.settings.cooldownDays
                                )
                            } else {
                                hapticFeedbackUndo()
                            }
                        }
                    }
                )
                .allowsHitTesting(!isViewingHistory)
            }

            // Top navigation - date display only
            VStack {
                Text(dateText)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(isViewingHistory ? dataManager.settings.highlightColor.color : .primary)
                    .padding(.top, 8)

                Spacer()
            }
        }
        .safeAreaInset(edge: .bottom) {
            // Bottom controls - slider and swap button
            HStack(spacing: 12) {
                Slider(
                    value: $daysOffset,
                    in: -7...7,
                    step: 1,
                    onEditingChanged: { editing in
                        if !editing {
                            // Snap back to center when finger is lifted
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                daysOffset = 0
                            }
                        }
                    }
                )
                .tint(dataManager.settings.highlightColor.color)
                .onChange(of: daysOffset) { oldValue, newValue in
                    if oldValue != newValue {
                        sliderDetentFeedback()
                    }
                }

                // Swap front/back button
                GlassCircleButton(
                    systemName: "arrow.trianglehead.2.clockwise",
                    color: dataManager.settings.highlightColor.color,
                    action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            currentSide = currentSide == .front ? .back : .front
                        }
                    }
                )
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }

    private func hapticFeedbackTap() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    private func hapticFeedbackUndo() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
    }

    private func sliderDetentFeedback() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
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
