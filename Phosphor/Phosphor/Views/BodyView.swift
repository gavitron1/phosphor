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

                // Layer 2: Controls overlay - centered vertically
                HStack {
                    Spacer()

                    // Right side: Swap button + Slider in VStack, centered
                    VStack(spacing: 16) {
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

                        // Camera-zoom style slider (1/3 of screen height)
                        CameraZoomSlider(
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
                        .frame(width: 50, height: geometry.size.height / 3)
                    }
                    .padding(.trailing, 8)
                }

                // Layer 3: Date label overlay
                VStack {
                    Text(showFeedback ? feedbackText : dateText)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(showFeedback ? dataManager.settings.highlightColor.color : (isViewingHistory ? dataManager.settings.highlightColor.color : .primary))
                        .padding(.top, 18)
                        .allowsHitTesting(false)
                        .animation(.easeInOut(duration: 0.3), value: showFeedback)
                        .id(showFeedback ? feedbackText : "date")

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

// MARK: - Camera Zoom Style Slider

struct CameraZoomSlider: View {
    @Binding var value: Double
    @Binding var isDragging: Bool
    let range: ClosedRange<Double>
    let highlightColor: Color
    let darkMode: Bool
    let onValueChanged: () -> Void
    let onRelease: () -> Void

    @State private var continuousDragValue: CGFloat = 0
    @State private var lastReportedIntValue: Double = 0

    private let tickSpacing: CGFloat = 24
    private let tickWidth: CGFloat = 16
    private let tickHeight: CGFloat = 2

    private var tickColor: Color {
        darkMode ? Color.white.opacity(0.3) : Color.black.opacity(0.15)
    }

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
            let tickCount = Int(range.upperBound - range.lowerBound) + 1

            ZStack {
                // Moving tick marks - use continuous value for smooth movement
                ForEach(0..<tickCount, id: \.self) { index in
                    let tickValue = range.lowerBound + Double(index)
                    // Use continuous drag value for smooth tick movement
                    let displayValue = isDragging ? continuousDragValue : value
                    let offsetFromValue = tickValue - displayValue
                    // Up = future (positive offset shows above center)
                    let tickY = centerY - (CGFloat(offsetFromValue) * tickSpacing)

                    // Only show ticks within visible range
                    if tickY > -tickSpacing && tickY < totalHeight + tickSpacing {
                        RoundedRectangle(cornerRadius: 1)
                            .fill(tickColor)
                            .frame(width: tickWidth, height: tickHeight)
                            .position(x: geometry.size.width - tickWidth / 2 - 4, y: tickY)
                    }
                }

                // Fixed indicator dot with day letter
                HStack(spacing: 6) {
                    // Day letter (visible when dragging)
                    Text(dayLetter(for: Int(value)))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(highlightColor)
                        .opacity(isDragging ? 1 : 0)
                        .animation(.easeInOut(duration: 0.15), value: isDragging)

                    // Fixed dot indicator
                    Circle()
                        .fill(highlightColor)
                        .frame(width: 8, height: 8)
                }
                .position(x: geometry.size.width / 2 - 4, y: centerY)

                // Invisible drag area
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { gesture in
                                // Set dragging immediately on touch
                                if !isDragging {
                                    isDragging = true
                                    continuousDragValue = value
                                }

                                // Dragging up (negative translation) = future (positive value)
                                // Dragging down (positive translation) = past (negative value)
                                let dragDistance = -gesture.translation.height
                                let valueChange = dragDistance / tickSpacing

                                // Continuous value for smooth tick movement
                                let newContinuousValue = max(range.lowerBound, min(valueChange, range.upperBound))
                                continuousDragValue = newContinuousValue

                                // Round to integer for actual value
                                let roundedValue = round(newContinuousValue)
                                let clampedValue = max(range.lowerBound, min(roundedValue, range.upperBound))

                                if clampedValue != lastReportedIntValue {
                                    lastReportedIntValue = clampedValue
                                    value = clampedValue
                                    onValueChanged()
                                }
                            }
                            .onEnded { _ in
                                isDragging = false
                                lastReportedIntValue = 0
                                continuousDragValue = 0
                                onRelease()
                            }
                    )
            }
            // Fade mask for top and bottom
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .black, location: 0.15),
                        .init(color: .black, location: 0.85),
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
