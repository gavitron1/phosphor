import SwiftUI

struct BodyView: View {
    @ObservedObject var dataManager = DataManager.shared
    @ObservedObject var notificationManager = NotificationManager.shared

    @State private var currentSide: BodySide = .front
    @State private var daysOffset: Double = 0 // -7 = 7 days ago, 0 = today, +7 = 7 days in future
    @State private var isDragging: Bool = false
    @State private var showCooldownPopover: Bool = false

    // Muscle feedback label state
    @State private var feedbackText: String = ""
    @State private var showFeedback: Bool = false
    @State private var feedbackTask: Task<Void, Never>?

    private var selectedDate: Date {
        Calendar.current.date(byAdding: .day, value: Int(daysOffset), to: Date()) ?? Date()
    }

    private var endOfDayDate: Date {
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

                // Layer 1: Body view - centered, 16pt smaller
                if daysOffset < 0 && !hasDataForSelectedDate {
                    VStack(spacing: 8) {
                        Text("No Data")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                    }
                } else {
                    TappableBodyView(
                        gender: dataManager.settings.gender,
                        side: currentSide,
                        highlightColor: dataManager.settings.highlightColor.color,
                        darkMode: dataManager.settings.darkMode,
                        cooldownDays: dataManager.settings.cooldownDays,
                        getIntensity: { muscleGroup in
                            if isViewingHistory {
                                return dataManager.getIntensity(for: muscleGroup, asOf: endOfDayDate)
                            } else {
                                return dataManager.getIntensity(for: muscleGroup)
                            }
                        },
                        onMuscleGroupTapped: { muscleGroup in
                            if !isViewingHistory {
                                let wasRecorded = dataManager.tapMuscleGroup(muscleGroup)
                                if wasRecorded {
                                    hapticFeedbackTap()
                                    showMuscleFeedback(muscleGroup.rawValue)
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
                    .frame(height: geometry.size.height - 8)
                }

                // Layer 2: Slider overlay - centered vertically on right side
                HStack {
                    Spacer()

                    // Right side: Vertical centered slider (1/3 of screen height)
                    CenteredVerticalSlider(
                        value: $daysOffset,
                        isDragging: $isDragging,
                        range: -7...7,
                        highlightColor: dataManager.settings.highlightColor.color,
                        onValueChanged: { sliderDetentFeedback() },
                        onRelease: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                daysOffset = 0
                            }
                        }
                    )
                    .frame(width: 60, height: geometry.size.height / 3)
                    .padding(.trailing, 8)
                }

                // Layer 3: Top bar overlay (clock button + date label + swap button)
                VStack {
                    HStack {
                        // Clock button (top left)
                        GlassCircleButton(
                            systemName: "clock.fill",
                            color: dataManager.settings.highlightColor.color,
                            action: {
                                showCooldownPopover = true
                            }
                        )
                        .popover(isPresented: $showCooldownPopover) {
                            CooldownPopoverView(dataManager: dataManager)
                        }

                        Spacer()

                        // Date/feedback label (center)
                        Text(showFeedback ? feedbackText : dateText)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(showFeedback ? dataManager.settings.highlightColor.color : (isViewingHistory ? dataManager.settings.highlightColor.color : .primary))
                            .allowsHitTesting(false)
                            .animation(.easeInOut(duration: 0.3), value: showFeedback)
                            .id(showFeedback ? feedbackText : "date")

                        Spacer()

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
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 8)

                    Spacer()
                }
            }
        }
        .gesture(
            DragGesture(minimumDistance: 50)
                .onEnded { gesture in
                    let horizontalDistance = gesture.translation.width
                    let verticalDistance = abs(gesture.translation.height)

                    if abs(horizontalDistance) > verticalDistance {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            currentSide = currentSide == .front ? .back : .front
                        }
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                    }
                }
        )
    }

    private func showMuscleFeedback(_ text: String) {
        feedbackTask?.cancel()
        feedbackText = text
        withAnimation(.easeIn(duration: 0.2)) {
            showFeedback = true
        }

        feedbackTask = Task {
            try? await Task.sleep(nanoseconds: 4_000_000_000)
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

// MARK: - Centered Vertical Slider

struct CenteredVerticalSlider: View {
    @Binding var value: Double
    @Binding var isDragging: Bool
    let range: ClosedRange<Double>
    let highlightColor: Color
    let onValueChanged: () -> Void
    let onRelease: () -> Void

    @State private var lastReportedIntValue: Double = 0

    private let trackWidth: CGFloat = 4
    private let handleSize: CGFloat = 24

    private func dayLetter(for offset: Int) -> String {
        let calendar = Calendar.current
        let date = calendar.date(byAdding: .day, value: offset, to: Date()) ?? Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEEE"
        return formatter.string(from: date)
    }

    var body: some View {
        GeometryReader { geometry in
            let totalHeight = geometry.size.height
            let centerY = totalHeight / 2
            let usableHeight = totalHeight - handleSize
            let rangeSpan = range.upperBound - range.lowerBound

            // Calculate handle position (up = future/positive, down = past/negative)
            let normalizedValue = value / rangeSpan
            let handleY = centerY - (CGFloat(normalizedValue) * usableHeight / 2)

            ZStack {
                // Track background
                RoundedRectangle(cornerRadius: trackWidth / 2)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: trackWidth, height: totalHeight)

                // Highlight fill from center
                if value != 0 {
                    let fillHeight = abs(CGFloat(normalizedValue) * usableHeight / 2)
                    let fillY = value > 0 ? centerY - fillHeight / 2 : centerY + fillHeight / 2

                    RoundedRectangle(cornerRadius: trackWidth / 2)
                        .fill(highlightColor)
                        .frame(width: trackWidth, height: fillHeight)
                        .position(x: geometry.size.width / 2, y: fillY)
                }

                // Handle with day letter
                HStack(spacing: 6) {
                    // Day letter (visible when dragging)
                    Text(dayLetter(for: Int(value)))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(highlightColor)
                        .opacity(isDragging ? 1 : 0)
                        .animation(.easeInOut(duration: 0.15), value: isDragging)

                    // White handle
                    Circle()
                        .fill(Color.white)
                        .frame(width: handleSize, height: handleSize)
                        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                }
                .position(x: geometry.size.width / 2 - 10, y: handleY)

                // Invisible drag area
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { gesture in
                                if !isDragging {
                                    isDragging = true
                                }

                                // Dragging up (negative translation) = future (positive value)
                                // Dragging down (positive translation) = past (negative value)
                                let dragDistance = -gesture.translation.height
                                let valuePerPoint = rangeSpan / Double(usableHeight)
                                let valueChange = dragDistance * valuePerPoint

                                let newValue = max(range.lowerBound, min(valueChange, range.upperBound))
                                let roundedValue = round(newValue)

                                if roundedValue != lastReportedIntValue {
                                    lastReportedIntValue = roundedValue
                                    value = roundedValue
                                    onValueChanged()
                                }
                            }
                            .onEnded { _ in
                                isDragging = false
                                lastReportedIntValue = 0
                                onRelease()
                            }
                    )
            }
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

// MARK: - Cooldown Popover View

struct CooldownPopoverView: View {
    @ObservedObject var dataManager: DataManager

    private var cooldownText: String {
        let days = Int(dataManager.settings.cooldownDays)
        return days == 1 ? "1 day" : "\(days) days"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recovery Time")
                .font(.headline)
                .fontWeight(.semibold)

            // Slider with tickmarks
            VStack(spacing: 8) {
                // Tickmarks
                HStack {
                    ForEach(1...7, id: \.self) { day in
                        Text("\(day)")
                            .font(.caption2)
                            .foregroundColor(Int(dataManager.settings.cooldownDays) == day ? dataManager.settings.highlightColor.color : .secondary)
                            .frame(maxWidth: .infinity)
                    }
                }

                // Slider
                Slider(
                    value: Binding(
                        get: { dataManager.settings.cooldownDays },
                        set: { dataManager.updateCooldownDays($0) }
                    ),
                    in: 1...7,
                    step: 1
                )
                .tint(dataManager.settings.highlightColor.color)
            }

            Text("Muscles will fully recover after \(cooldownText)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(20)
        .frame(width: 280)
        .presentationCompactAdaptation(.popover)
    }
}

#Preview {
    BodyView()
}
