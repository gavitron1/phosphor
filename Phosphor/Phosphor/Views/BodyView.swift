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
        GeometryReader { geometry in
            ZStack {
                // Background
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                HStack(spacing: 0) {
                    // Main content area
                    ZStack {
                        if daysOffset < 0 && !hasDataForSelectedDate {
                            // No data message (only for past dates)
                            VStack(spacing: 8) {
                                Text("No Data")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            // Body image view - 64pt taller, anchored to top
                            VStack(spacing: 0) {
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
                                .frame(height: geometry.size.height + 64)

                                Spacer(minLength: 0)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)

                    // Vertical tick slider on right side
                    VerticalTickSlider(
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
                    .frame(width: 44)
                    .padding(.trailing, 8)
                }
            }
        }
        .gesture(
            DragGesture(minimumDistance: 50)
                .onEnded { gesture in
                    let horizontalDistance = gesture.translation.width
                    let verticalDistance = abs(gesture.translation.height)

                    // Only trigger if horizontal movement is greater than vertical
                    if abs(horizontalDistance) > verticalDistance {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            currentSide = currentSide == .front ? .back : .front
                        }
                        // Haptic feedback for swipe
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                    }
                }
        )
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
            .padding(.trailing, 60)
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

// MARK: - Vertical Tick Slider

struct VerticalTickSlider: View {
    @Binding var value: Double
    @Binding var isDragging: Bool
    let range: ClosedRange<Double>
    let highlightColor: Color
    let darkMode: Bool
    let onValueChanged: () -> Void
    let onRelease: () -> Void

    @State private var lastReportedValue: Double = 0

    private let tickWidth: CGFloat = 20
    private let tickHeight: CGFloat = 2
    private let tickSpacing: CGFloat = 20

    private var tickColor: Color {
        darkMode ? Color.white.opacity(0.3) : Color.black.opacity(0.15)
    }

    // Get day letter for a given offset from today
    private func dayLetter(for offset: Int) -> String {
        let calendar = Calendar.current
        let date = calendar.date(byAdding: .day, value: offset, to: Date()) ?? Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEEE" // Single letter day
        return formatter.string(from: date)
    }

    var body: some View {
        GeometryReader { geometry in
            let totalHeight = geometry.size.height
            let tickCount = Int(range.upperBound - range.lowerBound) + 1
            let usableHeight = totalHeight - 60 // Padding for fade
            let centerY = totalHeight / 2

            ZStack {
                // Tick marks with day letters
                ForEach(0..<tickCount, id: \.self) { index in
                    let tickValue = range.lowerBound + Double(index)
                    let normalizedPosition = Double(index) / Double(tickCount - 1)
                    // Invert: top = future (+7), bottom = past (-7)
                    let tickY = 30 + (1 - normalizedPosition) * usableHeight
                    let isSelected = Int(value) == Int(tickValue)
                    let distanceFromSelected = abs(Int(tickValue) - Int(value))

                    HStack(spacing: 4) {
                        // Day letter (only visible when dragging)
                        Text(dayLetter(for: Int(tickValue)))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(isSelected ? highlightColor : (darkMode ? .white : .black).opacity(0.5))
                            .opacity(isDragging ? 1 : 0)
                            .animation(.easeInOut(duration: 0.15), value: isDragging)

                        // Tick mark
                        RoundedRectangle(cornerRadius: 1)
                            .fill(isSelected ? highlightColor : tickColor)
                            .frame(width: isSelected ? tickWidth : tickWidth * 0.6, height: tickHeight)
                            .animation(.easeInOut(duration: 0.1), value: isSelected)
                    }
                    .position(x: geometry.size.width / 2 - 2, y: tickY)
                }

                // Invisible drag area
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { gesture in
                                isDragging = true
                                let y = gesture.location.y
                                // Clamp to usable area
                                let clampedY = max(30, min(y, 30 + usableHeight))
                                // Invert: top = future, bottom = past
                                let percent = 1 - (clampedY - 30) / usableHeight
                                let newValue = range.lowerBound + (range.upperBound - range.lowerBound) * percent

                                // Round to nearest integer
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
            // Fade mask for top and bottom
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .black, location: 0.1),
                        .init(color: .black, location: 0.9),
                        .init(color: .clear, location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
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
