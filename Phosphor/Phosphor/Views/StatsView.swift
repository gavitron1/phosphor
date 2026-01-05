import SwiftUI

struct StatsView: View {
    @ObservedObject var dataManager = DataManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var displayedMonth: Date = Date()

    var body: some View {
        ZStack(alignment: .topLeading) {
            ScrollView {
                VStack(spacing: 16) {
                    summaryCard

                    calendarSection

                    statsListView
                }
                .padding()
                .padding(.top, 50)
            }
            .background(Color(.systemGroupedBackground))

            // Back button
            HStack {
                GlassCircleButton(
                    systemName: "chevron.left",
                    color: dataManager.settings.highlightColor.color,
                    action: { dismiss() }
                )
                .padding(.leading, 16)
                .padding(.top, 8)

                Spacer()
            }
        }
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
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
    }

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

    // MARK: - Calendar Section

    private var calendarSection: some View {
        VStack(spacing: 12) {
            // Month navigation
            HStack {
                Button(action: previousMonth) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(dataManager.settings.highlightColor.color)
                }

                Spacer()

                Text(monthYearString)
                    .font(.headline)

                Spacer()

                Button(action: nextMonth) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(dataManager.settings.highlightColor.color)
                }
            }
            .padding(.horizontal, 8)

            // Day headers
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                ForEach(["S", "M", "T", "W", "T", "F", "S"], id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
            }

            // Calendar days
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 4) {
                ForEach(calendarDays, id: \.self) { date in
                    if let date = date {
                        CalendarDayView(
                            date: date,
                            weight: dataManager.weight(for: date),
                            weightUnit: dataManager.settings.weightUnit,
                            isToday: Calendar.current.isDateInToday(date),
                            highlightColor: dataManager.settings.highlightColor.color
                        )
                    } else {
                        Color.clear
                            .frame(height: 50)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }

    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: displayedMonth)
    }

    private var calendarDays: [Date?] {
        let calendar = Calendar.current
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth))!
        let range = calendar.range(of: .day, in: .month, for: startOfMonth)!

        let firstWeekday = calendar.component(.weekday, from: startOfMonth)
        let leadingEmptyDays = firstWeekday - 1

        var days: [Date?] = Array(repeating: nil, count: leadingEmptyDays)

        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: startOfMonth) {
                days.append(date)
            }
        }

        // Add trailing empty days to complete the grid
        while days.count % 7 != 0 {
            days.append(nil)
        }

        return days
    }

    private func previousMonth() {
        if let newDate = Calendar.current.date(byAdding: .month, value: -1, to: displayedMonth) {
            displayedMonth = newDate
        }
    }

    private func nextMonth() {
        if let newDate = Calendar.current.date(byAdding: .month, value: 1, to: displayedMonth) {
            displayedMonth = newDate
        }
    }

    // MARK: - Stats List

    private var statsListView: some View {
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
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
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
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
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

// MARK: - Calendar Day View

struct CalendarDayView: View {
    let date: Date
    let weight: WeightEntry?
    let weightUnit: WeightUnit
    let isToday: Bool
    let highlightColor: Color

    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }

    var body: some View {
        VStack(spacing: 2) {
            Text(dayNumber)
                .font(.system(size: 14, weight: isToday ? .bold : .regular))
                .foregroundColor(isToday ? highlightColor : .primary)

            if let weight = weight {
                Text(String(format: "%.0f", weight.weight))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.secondary)
            } else {
                Text(" ")
                    .font(.system(size: 9))
            }
        }
        .frame(height: 40)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isToday ? highlightColor.opacity(0.1) : Color.clear)
        )
    }
}

#Preview {
    StatsView()
}
