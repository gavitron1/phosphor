import SwiftUI

struct BodyView: View {
    @ObservedObject var dataManager = DataManager.shared
    @ObservedObject var notificationManager = NotificationManager.shared

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

            // Top navigation
            VStack {
                HStack {
                    Spacer()

                    // Date display (center)
                    Text(dateText)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(isViewingHistory ? dataManager.settings.highlightColor.color : .primary)

                    Spacer()

                    // Swap front/back button (top right)
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
                .padding(.top, 8)

                Spacer()
            }
        }
        .safeAreaInset(edge: .bottom) {
            // History slider - full width above tab bar
            VStack(spacing: 0) {
                Slider(
                    value: $daysAgo,
                    in: 0...10,
                    step: 1
                )
                .tint(dataManager.settings.highlightColor.color)
                .scaleEffect(x: -1, y: 1) // Flip horizontally so 0 (today) is on right
                .onChange(of: daysAgo) { oldValue, newValue in
                    if oldValue != newValue {
                        sliderDetentFeedback()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
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
