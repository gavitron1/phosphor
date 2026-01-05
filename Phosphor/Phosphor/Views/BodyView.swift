import SwiftUI

enum WeightTrend {
    case up
    case down
    case stable
    case insufficient
}

enum CapsuleDisplayMode: Equatable {
    case weight
    case date
    case feedback(String)
}

struct BodyView: View {
    @ObservedObject var dataManager = DataManager.shared
    @ObservedObject var notificationManager = NotificationManager.shared
    @Environment(\.colorScheme) private var colorScheme

    @State private var currentSide: BodySide = .front
    @State private var daysOffset: Double = 0 // -7 = 7 days ago, 0 = today, +7 = 7 days in future
    @State private var isDragging: Bool = false
    @State private var showCooldownPopover: Bool = false
    @State private var showWeightInput: Bool = false
    @State private var showCalendar: Bool = false
    @State private var showSettings: Bool = false

    // Dynamic capsule state
    @State private var feedbackText: String = ""
    @State private var capsuleMode: CapsuleDisplayMode = .weight
    @State private var feedbackTask: Task<Void, Never>?

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

    private var weightDisplayText: String {
        if let weight = dataManager.settings.weight {
            let unit = dataManager.settings.weightUnit.rawValue
            return String(format: "%.1f %@", weight, unit)
        } else {
            return "Weight"
        }
    }

    private var weightTrend: WeightTrend {
        let entries = dataManager.weightHistory.suffix(7)
        guard entries.count >= 2 else { return .insufficient }

        let weights = entries.map { $0.weight }
        let first = weights.first!
        let last = weights.last!
        let diff = last - first

        if abs(diff) < 0.5 {
            return .stable
        } else if diff > 0 {
            return .up
        } else {
            return .down
        }
    }

    // Effective display mode for the dynamic capsule
    // Priority: feedback > date (when slider active) > weight
    private var effectiveDisplayMode: CapsuleDisplayMode {
        if case .feedback = capsuleMode {
            return capsuleMode
        } else if isDragging || daysOffset != 0 {
            return .date
        } else {
            return .weight
        }
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
                            // Body centered
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
                                .offset(y: -32)
                                .transaction { transaction in
                                    transaction.animation = nil
                                }
                            }

                            // Slider overlay on the right
                            HStack {
                                Spacer()
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
                                .frame(width: 56, height: geometry.size.height / 3)
                            }
                        }
                        .frame(height: geometry.size.height)

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
                // Layer 2: Button overlays
                VStack {
                    // Top row: Clock (left), Settings (right)
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

                        // Settings button (top right)
                        GlassCircleButton(
                            systemName: "gearshape.fill",
                            color: dataManager.settings.highlightColor.color,
                            action: {
                                showSettings = true
                            }
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                    Spacer()

                    // Bottom row: Calendar (left), Dynamic Capsule (center), Swap (right)
                    HStack {
                        // Calendar button (bottom left)
                        GlassCircleButton(
                            systemName: "calendar",
                            color: dataManager.settings.highlightColor.color,
                            action: {
                                showCalendar = true
                            }
                        )

                        Spacer()

                        // Dynamic capsule (center) - shows weight, date, or feedback
                        DynamicCapsuleButton(
                            mode: effectiveDisplayMode,
                            weightText: weightDisplayText,
                            dateText: dateText,
                            weightEntries: Array(dataManager.weightHistory.suffix(7)),
                            weightTrend: weightTrend,
                            highlightColor: dataManager.settings.highlightColor.color,
                            onWeightTap: {
                                showWeightInput = true
                            }
                        )

                        Spacer()

                        // Swap front/back button (bottom right)
                        GlassCircleButton(
                            systemName: "arrow.trianglehead.2.clockwise",
                            color: dataManager.settings.highlightColor.color,
                            action: {
                                currentSide = currentSide == .front ? .back : .front
                            }
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }
                .sheet(isPresented: $showWeightInput) {
                    WeightInputView(
                        currentWeight: dataManager.settings.weight,
                        weightUnit: dataManager.settings.weightUnit,
                        highlightColor: dataManager.settings.highlightColor.color,
                        onSave: { weight in
                            dataManager.updateWeight(weight)
                        }
                    )
                    .presentationDetents([.height(450)])
                }
                .sheet(isPresented: $showCalendar) {
                    CalendarView()
                }
                .sheet(isPresented: $showSettings) {
                    NavigationStack {
                        SettingsView()
                    }
                }
            }
        }
        .gesture(
            DragGesture(minimumDistance: 50)
                .onEnded { gesture in
                    let horizontalDistance = gesture.translation.width
                    let verticalDistance = abs(gesture.translation.height)

                    if abs(horizontalDistance) > verticalDistance {
                        currentSide = currentSide == .front ? .back : .front
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                    }
                }
        )
    }

    private func showMuscleFeedback(_ text: String) {
        feedbackTask?.cancel()
        feedbackText = text
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            capsuleMode = .feedback(text)
        }

        feedbackTask = Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if !Task.isCancelled {
                await MainActor.run {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        capsuleMode = .weight
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
    private let handleWidth: CGFloat = 12
    private let handleHeight: CGFloat = 24

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
            let usableHeight = totalHeight - handleHeight
            let rangeSpan = range.upperBound - range.lowerBound

            // Calculate handle position (up = future/positive, down = past/negative)
            // Handle can travel full height of slider
            let valueRatio = value / (rangeSpan / 2)  // -1 to 1 for the range
            let handleY = centerY - (CGFloat(valueRatio) * usableHeight / 2)
            // Position track at right side of frame (with 24pt inset)
            let trackX = geometry.size.width - trackWidth/2 - 24

            ZStack {
                // Track background
                RoundedRectangle(cornerRadius: trackWidth / 2)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: trackWidth, height: totalHeight)
                    .position(x: trackX, y: centerY)

                // Highlight fill from center
                if value != 0 {
                    let fillRatio = abs(value / (rangeSpan / 2))
                    let fillHeight = CGFloat(fillRatio) * usableHeight / 2
                    let fillY = value > 0 ? centerY - fillHeight / 2 : centerY + fillHeight / 2

                    RoundedRectangle(cornerRadius: trackWidth / 2)
                        .fill(highlightColor)
                        .frame(width: trackWidth, height: fillHeight)
                        .position(x: trackX, y: fillY)
                }

                // Day letter - positioned to the left of the track
                Text(dayLetter(for: Int(value)))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(highlightColor)
                    .position(x: trackX - 20, y: handleY)

                // Pill-shaped handle (2:1 ratio, fully rounded) - centered on track
                Capsule()
                    .fill(Color.white)
                    .frame(width: handleWidth, height: handleHeight)
                    .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                    .position(x: trackX, y: handleY)

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
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 52, height: 52)
        }
        .modifier(GlassCircleModifier())
    }
}

struct GlassCircleModifier: ViewModifier {
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

struct GlassCapsuleModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .background(.regularMaterial, in: Capsule())
                .glassEffect(.regular.interactive())
        } else {
            content
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
                )
        }
    }
}

// MARK: - Dynamic Capsule Button

struct DynamicCapsuleButton: View {
    let mode: CapsuleDisplayMode
    let weightText: String
    let dateText: String
    let weightEntries: [WeightEntry]
    let weightTrend: WeightTrend
    let highlightColor: Color
    let onWeightTap: () -> Void

    var body: some View {
        Button(action: {
            // Only respond to tap when showing weight
            if case .weight = mode {
                onWeightTap()
            }
        }) {
            HStack(spacing: 8) {
                switch mode {
                case .weight:
                    Text(weightText)
                        .font(.body.weight(.semibold))
                        .foregroundColor(highlightColor)

                    WeightSparkline(
                        entries: weightEntries,
                        trend: weightTrend,
                        color: highlightColor
                    )
                    .frame(width: 32, height: 18)

                case .date:
                    Text(dateText)
                        .font(.body.weight(.semibold))
                        .foregroundColor(highlightColor)

                case .feedback(let text):
                    Text(text)
                        .font(.body.weight(.semibold))
                        .foregroundColor(highlightColor)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .modifier(GlassCapsuleModifier())
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: mode)
    }
}

// MARK: - Weight Sparkline

struct WeightSparkline: View {
    let entries: [WeightEntry]
    let trend: WeightTrend
    let color: Color

    var body: some View {
        GeometryReader { geometry in
            if entries.count < 2 {
                // Null state - show dash
                Rectangle()
                    .fill(color.opacity(0.3))
                    .frame(width: geometry.size.width, height: 2)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            } else {
                // Draw sparkline
                let weights = entries.map { $0.weight }
                let minWeight = weights.min() ?? 0
                let maxWeight = weights.max() ?? 1
                let range = maxWeight - minWeight
                let effectiveRange = range > 0 ? range : 1

                Path { path in
                    for (index, weight) in weights.enumerated() {
                        let x = CGFloat(index) / CGFloat(weights.count - 1) * geometry.size.width
                        let normalizedY = (weight - minWeight) / effectiveRange
                        let y = geometry.size.height - (normalizedY * geometry.size.height)

                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(color, lineWidth: 2)
            }
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

// MARK: - Weight Input View

struct WeightInputView: View {
    let currentWeight: Double?
    let weightUnit: WeightUnit
    let highlightColor: Color
    let onSave: (Double?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var weightString: String = ""
    @State private var isEditing: Bool = false  // Track if user started typing

    // Show placeholder (current weight) in gray, or user input in primary color
    private var displayWeight: String {
        if isEditing {
            return weightString.isEmpty ? "0" : weightString
        } else if let weight = currentWeight {
            return String(format: "%.1f", weight)
        } else {
            return "0"
        }
    }

    private var displayColor: Color {
        isEditing ? .primary : .secondary
    }

    var body: some View {
        VStack(spacing: 16) {
            // Header with drag indicator
            VStack(spacing: 12) {
                Capsule()
                    .fill(Color(.systemGray4))
                    .frame(width: 36, height: 5)
                    .padding(.top, 8)

                Spacer()
                    .frame(height: 16)

                HStack {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.secondary)
                    .font(.body)

                    Spacer()

                    Text("Weight")
                        .font(.headline)
                        .fontWeight(.semibold)

                    Spacer()

                    Button("Save") {
                        if isEditing, let weight = Double(weightString), weight > 0 {
                            onSave(weight)
                        }
                        dismiss()
                    }
                    .foregroundColor(highlightColor)
                    .fontWeight(.semibold)
                }
                .padding(.horizontal, 20)
            }

            // Weight display
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(displayWeight)
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundColor(displayColor)
                Text(weightUnit.rawValue)
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 12)

            // Numpad
            VStack(spacing: 10) {
                ForEach(0..<3) { row in
                    HStack(spacing: 10) {
                        ForEach(1...3, id: \.self) { col in
                            let number = row * 3 + col
                            NumpadButton(label: "\(number)", highlightColor: highlightColor) {
                                appendDigit("\(number)")
                            }
                        }
                    }
                }

                HStack(spacing: 10) {
                    NumpadButton(label: ".", highlightColor: highlightColor) {
                        appendDecimal()
                    }
                    NumpadButton(label: "0", highlightColor: highlightColor) {
                        appendDigit("0")
                    }
                    NumpadButton(systemImage: "delete.left", highlightColor: highlightColor) {
                        deleteLastDigit()
                    }
                }
            }
            .padding(.horizontal, 20)

            Spacer()
        }
        .background(Color(.systemBackground))
    }

    private func appendDigit(_ digit: String) {
        // First digit clears the placeholder and starts fresh
        if !isEditing {
            isEditing = true
            weightString = digit
        } else if weightString.count < 5 {
            weightString += digit
        }
    }

    private func appendDecimal() {
        if !isEditing {
            isEditing = true
            weightString = "0."
        } else if !weightString.contains(".") {
            if weightString.isEmpty {
                weightString = "0."
            } else {
                weightString += "."
            }
        }
    }

    private func deleteLastDigit() {
        if isEditing && !weightString.isEmpty {
            weightString.removeLast()
            // If we deleted everything, go back to placeholder mode
            if weightString.isEmpty {
                isEditing = false
            }
        }
    }
}

struct NumpadButton: View {
    let label: String?
    let systemImage: String?
    let highlightColor: Color
    let action: () -> Void

    init(label: String, highlightColor: Color, action: @escaping () -> Void) {
        self.label = label
        self.systemImage = nil
        self.highlightColor = highlightColor
        self.action = action
    }

    init(systemImage: String, highlightColor: Color, action: @escaping () -> Void) {
        self.label = nil
        self.systemImage = systemImage
        self.highlightColor = highlightColor
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Group {
                if let label = label {
                    Text(label)
                        .font(.system(size: 28, weight: .medium))
                } else if let systemImage = systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 24, weight: .medium))
                }
            }
            .foregroundColor(.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
    }
}

#Preview {
    BodyView()
}
