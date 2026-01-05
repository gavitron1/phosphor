import SwiftUI

struct CalendarView: View {
    @ObservedObject var dataManager = DataManager.shared

    @State private var selectedDate: Date = Date()
    @State private var currentMonth: Date = Date()

    private let calendar = Calendar.current
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()

    var body: some View {
        VStack(spacing: 16) {
            // Month header with navigation
            HStack {
                Button(action: previousMonth) {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .foregroundColor(dataManager.settings.highlightColor.color)
                }

                Spacer()

                Text(dateFormatter.string(from: currentMonth))
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                Button(action: nextMonth) {
                    Image(systemName: "chevron.right")
                        .font(.title2)
                        .foregroundColor(dataManager.settings.highlightColor.color)
                }
            }
            .padding(.horizontal)
            .padding(.top, 16)

                // Day headers
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                    ForEach(Array(["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"].enumerated()), id: \.offset) { _, day in
                        Text(day)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)

                // Calendar grid
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 4) {
                    ForEach(daysInMonth(), id: \.self) { date in
                        if let date = date {
                            CalendarDayCell(
                                date: date,
                                isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                                hasActivity: hasActivityOnDate(date),
                                weight: dataManager.getWeight(for: date),
                                highlightColor: dataManager.settings.highlightColor.color,
                                onTap: { selectedDate = date }
                            )
                        } else {
                            Text("")
                                .frame(height: 56)
                        }
                    }
                }
                .padding(.horizontal)

                Divider()
                    .padding(.vertical, 8)

                // Mini avatar showing selected date's state
                VStack(spacing: 8) {
                    Text(selectedDateText)
                        .font(.headline)
                        .foregroundColor(.secondary)

                    HStack(spacing: 20) {
                        // Front view
                        VStack {
                            MiniBodyView(
                                gender: dataManager.settings.gender,
                                side: .front,
                                highlightColor: dataManager.settings.highlightColor.color,
                                darkMode: dataManager.settings.darkMode,
                                getIntensity: { group in
                                    dataManager.getIntensity(for: group, asOf: endOfSelectedDate)
                                }
                            )
                            .frame(height: 200)

                            Text("Front")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        // Back view
                        VStack {
                            MiniBodyView(
                                gender: dataManager.settings.gender,
                                side: .back,
                                highlightColor: dataManager.settings.highlightColor.color,
                                darkMode: dataManager.settings.darkMode,
                                getIntensity: { group in
                                    dataManager.getIntensity(for: group, asOf: endOfSelectedDate)
                                }
                            )
                            .frame(height: 200)

                            Text("Back")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

            Spacer()
        }
        .background(Color(.systemGroupedBackground))
    }

    private var selectedDateText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: selectedDate)
    }

    private var endOfSelectedDate: Date {
        let startOfDay = calendar.startOfDay(for: selectedDate)
        return calendar.date(byAdding: .second, value: 86399, to: startOfDay) ?? selectedDate
    }

    private func previousMonth() {
        if let newDate = calendar.date(byAdding: .month, value: -1, to: currentMonth) {
            currentMonth = newDate
        }
    }

    private func nextMonth() {
        if let newDate = calendar.date(byAdding: .month, value: 1, to: currentMonth) {
            currentMonth = newDate
        }
    }

    private func daysInMonth() -> [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: currentMonth),
              let monthFirstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start) else {
            return []
        }

        var days: [Date?] = []
        let firstDayOfMonth = monthInterval.start
        let firstWeekday = calendar.component(.weekday, from: firstDayOfMonth)

        // Add empty cells for days before the first of the month
        for _ in 1..<firstWeekday {
            days.append(nil)
        }

        // Add all days in the month
        var currentDate = firstDayOfMonth
        while currentDate < monthInterval.end {
            days.append(currentDate)
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }

        return days
    }

    private func hasActivityOnDate(_ date: Date) -> Bool {
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date

        for (_, data) in dataManager.muscleGroupData {
            if let lastTapped = data.lastTappedDate {
                if lastTapped >= startOfDay && lastTapped < endOfDay {
                    return true
                }
            }
        }
        return false
    }
}

struct CalendarDayCell: View {
    let date: Date
    let isSelected: Bool
    let hasActivity: Bool
    let weight: Double?
    let highlightColor: Color
    let onTap: () -> Void

    private let calendar = Calendar.current

    private var isToday: Bool {
        calendar.isDateInToday(date)
    }

    private var dayTextColor: Color {
        if isSelected {
            return .white
        } else if isToday {
            return highlightColor
        } else if hasActivity {
            return highlightColor
        } else {
            return .primary
        }
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 2) {
                Text("\(calendar.component(.day, from: date))")
                    .font(.system(size: 14, weight: (isToday || hasActivity) ? .bold : .regular))
                    .foregroundColor(dayTextColor)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(isSelected ? highlightColor : Color.clear)
                    )

                // Weight display
                if let weight = weight {
                    Text(String(format: "%.0f", weight))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                } else {
                    Text(" ")
                        .font(.system(size: 9))
                }
            }
            .frame(height: 52)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct MiniBodyView: View {
    let gender: Gender
    let side: BodySide
    let highlightColor: Color
    let darkMode: Bool
    let getIntensity: (MuscleGroup) -> Double

    private var baseColor: Color {
        darkMode ? .black : .white
    }

    private func muscleColor(for intensity: Double) -> Color {
        if intensity <= 0 {
            return baseColor
        }
        return Color(
            UIColor(highlightColor).interpolate(to: UIColor(baseColor), fraction: 1.0 - intensity)
        )
    }

    private var muscleGroups: [MuscleGroup] {
        side == .front ? MuscleGroup.frontMuscles : MuscleGroup.backMuscles
    }

    private func imageName(for muscleGroup: MuscleGroup) -> String? {
        side == .front ? muscleGroup.frontImageName(for: gender) : muscleGroup.backImageName(for: gender)
    }

    private var blackBackgroundImage: Image {
        let prefix = gender == .male ? "male" : "female"
        let sideStr = side == .front ? "front" : "back"
        return Image("\(prefix)-\(sideStr)-body-bkg-black")
    }

    private var whiteBackgroundImage: Image {
        let prefix = gender == .male ? "male" : "female"
        let sideStr = side == .front ? "front" : "back"
        return Image("\(prefix)-\(sideStr)-body-bkg-white")
    }

    private var nonTappableOverlay: Image {
        let prefix = gender == .male ? "male" : "female"
        let sideStr = side == .front ? "front" : "back"
        if side == .front && gender == .male {
            return Image("\(prefix)-\(sideStr)-hands-feet-hair")
        } else {
            return Image("\(prefix)-\(sideStr)-body-hands-feet-knees")
        }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if darkMode {
                    whiteBackgroundImage
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .colorInvert()

                    blackBackgroundImage
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .colorInvert()
                } else {
                    blackBackgroundImage
                        .resizable()
                        .aspectRatio(contentMode: .fit)

                    whiteBackgroundImage
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .colorInvert()
                }

                ForEach(muscleGroups, id: \.self) { muscleGroup in
                    if let imageName = imageName(for: muscleGroup),
                       let uiImage = UIImage(named: imageName) {
                        let intensity = getIntensity(muscleGroup)
                        Image(uiImage: uiImage.withRenderingMode(.alwaysTemplate))
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .foregroundColor(muscleColor(for: intensity))
                    }
                }

                if darkMode {
                    nonTappableOverlay
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .colorInvert()
                } else {
                    nonTappableOverlay
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
}

#Preview {
    CalendarView()
}
