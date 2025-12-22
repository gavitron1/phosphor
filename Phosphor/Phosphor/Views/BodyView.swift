import SwiftUI

struct BodyView: View {
    @ObservedObject var dataManager = DataManager.shared
    @ObservedObject var notificationManager = NotificationManager.shared

    @State private var currentSide: BodySide = .front
    @State private var daysOffset: Double = 0 // -7 = 7 days ago, 0 = today, +7 = 7 days in future
    @State private var isDragging: Bool = false

    // Muscle feedback label state
    @State private var feedbackText: String = ""
    @State private var showFeedback: Bool = false
    @State private var feedbackTask: Task<Void, Never>?

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
                                showMuscleFeedback(muscleGroup.rawValue)
                                // Schedule cooldown notifications
                                notificationManager.scheduleCooldownNotifications(
                                    muscleData: dataManager.muscleGroupData,
                                    cooldownDays: dataManager.settings.cooldownDays
                                )
                            } else {
                                hapticFeedbackUndo()
                                showMuscleFeedback("\(muscleGroup.rawValue) Removed")
                            }
                        }
                    }
                )
            }
        }
        .overlay(alignment: .topTrailing) {
            // Swap front/back button (top right)
            GlassCircleButton(
                systemName: "arrow.trianglehead.2.clockwise",
                color: dataManager.settings.highlightColor.color,
                action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        currentSide = currentSide == .front ? .back : .front
                    }
                }
            )
            .padding(.trailing, 16)
            .padding(.top, 8)
        }
        .overlay(alignment: .top) {
            // Date/feedback display (center top)
            Text(showFeedback ? feedbackText : dateText)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(showFeedback ? dataManager.settings.highlightColor.color : (isViewingHistory ? dataManager.settings.highlightColor.color : .primary))
                .padding(.top, 18)
                .allowsHitTesting(false)
                .animation(.easeInOut(duration: 0.3), value: showFeedback)
                .id(showFeedback ? feedbackText : "date") // Force view recreation for animation
        }
        .safeAreaInset(edge: .bottom) {
            // Custom centered slider
            CenteredSlider(
                value: $daysOffset,
                isDragging: $isDragging,
                range: -7...7,
                highlightColor: dataManager.settings.highlightColor.color,
                darkMode: dataManager.settings.darkMode,
                onValueChanged: { sliderDetentFeedback() },
                onRelease: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        daysOffset = 0
                    }
                }
            )
            .padding(.horizontal, 32)
            .padding(.bottom, 16)
        }
    }

    private func showMuscleFeedback(_ text: String) {
        // Cancel any existing fade-out task
        feedbackTask?.cancel()

        // Show the feedback
        feedbackText = text
        withAnimation(.easeIn(duration: 0.2)) {
            showFeedback = true
        }

        // Schedule fade-out after 4 seconds
        feedbackTask = Task {
            try? await Task.sleep(nanoseconds: 4_000_000_000) // 4 seconds
            if !Task.isCancelled {
                await MainActor.run {
                    withAnimation(.easeOut(duration: 0.3)) {
                        showFeedback = false
                    }
                }
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

// MARK: - Centered Slider

struct CenteredSlider: View {
    @Binding var value: Double
    @Binding var isDragging: Bool
    let range: ClosedRange<Double>
    let highlightColor: Color
    let darkMode: Bool
    let onValueChanged: () -> Void
    let onRelease: () -> Void

    @State private var lastReportedValue: Double = 0

    private let trackHeight: CGFloat = 6
    private let thumbSize: CGFloat = 28

    private var trackColor: Color {
        darkMode ? Color.white.opacity(0.2) : Color.black.opacity(0.1)
    }

    var body: some View {
        GeometryReader { geometry in
            let totalWidth = geometry.size.width
            let usableWidth = totalWidth - thumbSize
            let centerX = totalWidth / 2
            let rangeSpan = range.upperBound - range.lowerBound
            let valuePercent = (value - range.lowerBound) / rangeSpan
            let thumbX = thumbSize / 2 + usableWidth * valuePercent

            ZStack(alignment: .leading) {
                // Track background
                Capsule()
                    .fill(trackColor)
                    .frame(height: trackHeight)

                // Highlight fill from center
                let fillWidth = abs(thumbX - centerX)
                let fillX = value >= 0 ? centerX : thumbX

                Capsule()
                    .fill(highlightColor)
                    .frame(width: fillWidth, height: trackHeight)
                    .position(x: fillX + fillWidth / 2, y: geometry.size.height / 2)

                // Thumb
                Circle()
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                    .frame(width: thumbSize, height: thumbSize)
                    .position(x: thumbX, y: geometry.size.height / 2)
            }
            .frame(height: geometry.size.height)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        isDragging = true
                        let newX = gesture.location.x
                        let clampedX = max(thumbSize / 2, min(newX, totalWidth - thumbSize / 2))
                        let percent = (clampedX - thumbSize / 2) / usableWidth
                        let newValue = range.lowerBound + rangeSpan * percent

                        // Round to nearest integer for detent feel
                        let roundedValue = round(newValue)
                        let clampedValue = max(range.lowerBound, min(roundedValue, range.upperBound))

                        if clampedValue != lastReportedValue {
                            lastReportedValue = clampedValue
                            value = clampedValue
                            onValueChanged()
                        }
                    }
                    .onEnded { _ in
                        isDragging = false
                        onRelease()
                    }
            )
        }
        .frame(height: thumbSize + 16)
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
