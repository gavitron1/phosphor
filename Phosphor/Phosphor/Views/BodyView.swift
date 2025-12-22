import SwiftUI

struct BodyView: View {
    @ObservedObject var dataManager = DataManager.shared
    @ObservedObject var notificationManager = NotificationManager.shared
    @Environment(\.colorScheme) private var colorScheme

    @State private var currentSide: BodySide = .front
    @State private var daysOffset: Double = 0 // -7 = 7 days ago, 0 = today, +7 = 7 days in future
    @State private var isDragging: Bool = false
    @State private var showCooldownPopover: Bool = false

    // Muscle feedback label state
    @State private var feedbackText: String = ""
    @State private var showFeedback: Bool = false
    @State private var feedbackTask: Task<Void, Never>?

    // Scroll tracking
    @State private var scrollOffset: CGFloat = 0
    @State private var initialScrollOffset: CGFloat? = nil

    // Effective dark mode based on appearance setting and system color scheme
    private var effectiveDarkMode: Bool {
        switch dataManager.settings.appearanceMode {
        case .dark:
            return true
        case .light:
            return false
        case .system:
            return colorScheme == .dark
        }
    }

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

    // MARK: - Stats computed properties

    private var totalTaps: Int {
        dataManager.muscleGroupData.values.reduce(0) { $0 + $1.tapCount }
    }

    private var activeMuscleCount: Int {
        dataManager.muscleGroupData.values.filter { data in
            data.intensity(cooldownDays: dataManager.settings.cooldownDays) > 0
        }.count
    }

    private var mostTrained: MuscleGroupData? {
        dataManager.getSortedMuscleGroups().first(where: { $0.tapCount > 0 })
    }

    private var leastTrained: MuscleGroupData? {
        let sorted = dataManager.getSortedMuscleGroups().filter { $0.tapCount > 0 }
        return sorted.last
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                // Scrollable content
                ScrollView {
                    VStack(spacing: 0) {
                        // Body avatar section (screen height)
                        ZStack {
                            if daysOffset < 0 && !hasDataForSelectedDate {
                                VStack(spacing: 8) {
                                    Text("No Data")
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.secondary)
                                }
                                .frame(height: geometry.size.height)
                            } else {
                                TappableBodyView(
                                    gender: dataManager.settings.gender,
                                    side: currentSide,
                                    highlightColor: dataManager.settings.highlightColor.color,
                                    darkMode: effectiveDarkMode,
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
                                .frame(height: geometry.size.height + 8)
                            }
                        }
                        .frame(height: geometry.size.height)
                        .background(
                            GeometryReader { proxy in
                                Color.clear
                                    .preference(
                                        key: ScrollOffsetPreferenceKey.self,
                                        value: proxy.frame(in: .global).minY
                                    )
                            }
                        )

                        // Statistics section (below the fold)
                        VStack(spacing: 16) {
                            Text("Statistics")
                                .font(.title2)
                                .fontWeight(.bold)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            // Summary cards
                            VStack(spacing: 12) {
                                HStack {
                                    StatBox(
                                        title: "Total Taps",
                                        value: "\(totalTaps)",
                                        icon: "hand.tap.fill",
                                        color: dataManager.settings.highlightColor.color
                                    )

                                    StatBox(
                                        title: "Active Muscles",
                                        value: "\(activeMuscleCount)",
                                        icon: "flame.fill",
                                        color: .orange
                                    )
                                }

                                HStack {
                                    StatBox(
                                        title: "Most Trained",
                                        value: mostTrained?.muscleGroup.rawValue ?? "None",
                                        icon: "trophy.fill",
                                        color: .yellow
                                    )

                                    StatBox(
                                        title: "Needs Work",
                                        value: leastTrained?.muscleGroup.rawValue ?? "None",
                                        icon: "exclamationmark.triangle.fill",
                                        color: .red
                                    )
                                }
                            }

                            // Muscle groups list
                            VStack(spacing: 12) {
                                HStack {
                                    Text("Muscle Groups")
                                        .font(.headline)
                                    Spacer()
                                    Text("Tap Count")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 4)

                                LazyVStack(spacing: 8) {
                                    ForEach(dataManager.getSortedMuscleGroups()) { data in
                                        MuscleStatRow(
                                            data: data,
                                            maxCount: dataManager.getMaxTapCount(),
                                            highlightColor: dataManager.settings.highlightColor.color,
                                            cooldownDays: dataManager.settings.cooldownDays
                                        )
                                    }
                                }
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color(.secondarySystemBackground))
                            )
                        }
                        .padding()
                    }
                }
                .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                    if initialScrollOffset == nil {
                        initialScrollOffset = value
                    }
                    scrollOffset = value
                }

                // Layer 2: Slider overlay - hide when scrolled down
                // Show slider when at top (within 50pts of initial position)
                if initialScrollOffset == nil || scrollOffset > (initialScrollOffset! - 50) {
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
                    .transition(.opacity)
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
    @GestureState private var dragOffset: CGFloat = 0

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
            // Handle can travel full height of slider
            let valueRatio = value / (rangeSpan / 2)  // -1 to 1 for the range
            let handleY = centerY - (CGFloat(valueRatio) * usableHeight / 2)

            ZStack {
                // Track background
                RoundedRectangle(cornerRadius: trackWidth / 2)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: trackWidth, height: totalHeight)

                // Highlight fill from center
                if value != 0 {
                    let fillRatio = abs(value / (rangeSpan / 2))
                    let fillHeight = CGFloat(fillRatio) * usableHeight / 2
                    let fillY = value > 0 ? centerY - fillHeight / 2 : centerY + fillHeight / 2

                    RoundedRectangle(cornerRadius: trackWidth / 2)
                        .fill(highlightColor)
                        .frame(width: trackWidth, height: fillHeight)
                        .position(x: geometry.size.width / 2, y: fillY)
                }

                // Handle with day letter - always visible
                HStack(spacing: 6) {
                    // Day letter (always shown)
                    Text(dayLetter(for: Int(value)))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(highlightColor)

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
                                let pointsPerValue = usableHeight / CGFloat(rangeSpan)
                                let valueChange = dragDistance / pointsPerValue

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

// MARK: - Stat Box

struct StatBox: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.system(size: 14))
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text(value)
                .font(.system(size: 18, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

// MARK: - Muscle Stat Row

struct MuscleStatRow: View {
    let data: MuscleGroupData
    let maxCount: Int
    let highlightColor: Color
    let cooldownDays: Double

    var body: some View {
        HStack(spacing: 12) {
            // Icon with intensity
            ZStack {
                Circle()
                    .fill(highlightColor.opacity(data.intensity(cooldownDays: cooldownDays)))
                    .frame(width: 40, height: 40)

                Image(systemName: data.muscleGroup.systemImage)
                    .font(.system(size: 16))
                    .foregroundColor(data.intensity(cooldownDays: cooldownDays) > 0.5 ? .white : .primary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(data.muscleGroup.rawValue)
                    .font(.subheadline)
                    .fontWeight(.medium)

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background bar
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(.systemGray5))
                            .frame(height: 8)

                        // Progress bar
                        RoundedRectangle(cornerRadius: 4)
                            .fill(highlightColor)
                            .frame(width: barWidth(in: geometry.size.width), height: 8)
                    }
                }
                .frame(height: 8)
            }

            Text("\(data.tapCount)")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(.secondary)
                .frame(minWidth: 40, alignment: .trailing)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
    }

    private func barWidth(in totalWidth: CGFloat) -> CGFloat {
        guard maxCount > 0 else { return 0 }
        let percentage = CGFloat(data.tapCount) / CGFloat(maxCount)
        return totalWidth * percentage
    }
}

// MARK: - Scroll Offset Preference Key

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

#Preview {
    BodyView()
}
