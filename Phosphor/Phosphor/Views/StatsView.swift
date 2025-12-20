import SwiftUI

struct StatsView: View {
    @ObservedObject var dataManager = DataManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topLeading) {
            ScrollView {
                VStack(spacing: 16) {
                    summaryCard

                    statsListView
                }
                .padding()
                .padding(.top, 50)
            }
            .background(Color(.systemGroupedBackground))

            // Back button
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left.circle.fill")
                        .font(.system(size: 36))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(dataManager.settings.highlightColor.color)
                }
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

#Preview {
    StatsView()
}
