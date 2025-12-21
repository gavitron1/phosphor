import SwiftUI

enum CooldownMode: String, CaseIterable {
    case minutes = "Minutes"
    case days = "Days"
}

struct SettingsView: View {
    @ObservedObject var dataManager = DataManager.shared
    @ObservedObject var cloudKitManager = CloudKitManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var deleteError: String?
    @State private var cooldownMode: CooldownMode = .days

    var body: some View {
        ZStack(alignment: .topLeading) {
            Form {
                genderSection

                appearanceSection

                highlightColorSection

                cooldownSection

                syncSection

                iCloudSection

                dangerZoneSection
            }
            .padding(.top, 50)

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
        .alert("Delete All Data", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteAllData()
            }
        } message: {
            Text("This will permanently delete all your workout data from this device and iCloud. This action cannot be undone.")
        }
        .alert("Error", isPresented: .init(
            get: { deleteError != nil },
            set: { if !$0 { deleteError = nil } }
        )) {
            Button("OK") { deleteError = nil }
        } message: {
            Text(deleteError ?? "An error occurred")
        }
    }

    // MARK: - Gender Section

    private var genderSection: some View {
        Section {
            Picker("Body Type", selection: Binding(
                get: { dataManager.settings.gender },
                set: { dataManager.updateGender($0) }
            )) {
                ForEach(Gender.allCases, id: \.self) { gender in
                    Text(gender.rawValue).tag(gender)
                }
            }
            .pickerStyle(.segmented)
        } header: {
            Text("Body Type")
        }
    }

    // MARK: - Appearance Section

    private var appearanceSection: some View {
        Section {
            Toggle("Dark Mode", isOn: Binding(
                get: { dataManager.settings.darkMode },
                set: { dataManager.updateDarkMode($0) }
            ))
        } header: {
            Text("Appearance")
        } footer: {
            Text("Inverts the body figure colors for dark backgrounds.")
        }
    }

    // MARK: - Sync Section

    private var syncSection: some View {
        Section {
            Button(action: {
                Task {
                    await dataManager.syncFromCloud()
                }
            }) {
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text("Refresh Data")
                    Spacer()
                    if dataManager.isLoading {
                        ProgressView()
                    }
                }
            }
            .disabled(dataManager.isLoading)

            // Show sync error if present
            if let error = dataManager.syncError {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        } header: {
            Text("Sync")
        }
    }

    // MARK: - Highlight Color Section

    private var highlightColorSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Text("Choose your highlight color")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                    ForEach(Array(CodableColor.presetColors.enumerated()), id: \.offset) { index, presetColor in
                        ColorButton(
                            color: presetColor,
                            isSelected: isColorSelected(presetColor),
                            action: {
                                dataManager.updateHighlightColor(presetColor)
                            }
                        )
                    }
                }
            }
            .padding(.vertical, 8)
        } header: {
            Text("Highlight Color")
        }
    }

    private func isColorSelected(_ color: CodableColor) -> Bool {
        let current = dataManager.settings.highlightColor
        return abs(current.red - color.red) < 0.01 &&
               abs(current.green - color.green) < 0.01 &&
               abs(current.blue - color.blue) < 0.01
    }

    // MARK: - Cooldown Section

    private var cooldownSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                // Mode toggle
                Picker("Mode", selection: $cooldownMode) {
                    ForEach(CooldownMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                // Preset buttons based on mode
                if cooldownMode == .minutes {
                    minutesPresetButtons
                } else {
                    daysPresetButtons
                }

                Text("Muscle groups will fade completely after \(cooldownText)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        } header: {
            Text("Cooldown Time")
        } footer: {
            Text("The highlight intensity will gradually decrease from 100% to 0% over this period.")
        }
    }

    private var minutesPresetButtons: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
            ForEach(minutesPresets, id: \.value) { preset in
                Button(action: {
                    dataManager.updateCooldownDays(preset.value)
                }) {
                    Text(preset.label)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            isPresetSelected(preset.value)
                                ? dataManager.settings.highlightColor.color
                                : Color(.systemGray5)
                        )
                        .foregroundColor(isPresetSelected(preset.value) ? .white : .primary)
                        .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }

    private var daysPresetButtons: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 8) {
            ForEach(daysPresets, id: \.value) { preset in
                Button(action: {
                    dataManager.updateCooldownDays(preset.value)
                }) {
                    Text(preset.label)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            isPresetSelected(preset.value)
                                ? dataManager.settings.highlightColor.color
                                : Color(.systemGray5)
                        )
                        .foregroundColor(isPresetSelected(preset.value) ? .white : .primary)
                        .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }

    private var minutesPresets: [(label: String, value: Double)] {
        [
            ("10 sec", 10.0 / 86400.0),
            ("30 sec", 30.0 / 86400.0),
            ("1 min", 60.0 / 86400.0),
            ("2 min", 120.0 / 86400.0),
            ("3 min", 180.0 / 86400.0),
            ("5 min", 300.0 / 86400.0)
        ]
    }

    private var daysPresets: [(label: String, value: Double)] {
        [
            ("1 day", 1.0),
            ("2 days", 2.0),
            ("3 days", 3.0),
            ("4 days", 4.0),
            ("5 days", 5.0),
            ("6 days", 6.0),
            ("7 days", 7.0)
        ]
    }

    private func isPresetSelected(_ value: Double) -> Bool {
        abs(dataManager.settings.cooldownDays - value) < 0.001
    }

    private var cooldownText: String {
        let days = dataManager.settings.cooldownDays
        let totalSeconds = days * 86400

        if totalSeconds < 60 {
            return "\(Int(totalSeconds)) seconds"
        } else if totalSeconds < 3600 {
            let minutes = Int(totalSeconds / 60)
            return minutes == 1 ? "1 minute" : "\(minutes) minutes"
        } else if days < 1 {
            let hours = Int(totalSeconds / 3600)
            return hours == 1 ? "1 hour" : "\(hours) hours"
        } else if days == 1 {
            return "1 day"
        } else if days == floor(days) {
            return "\(Int(days)) days"
        } else {
            return String(format: "%.1f days", days)
        }
    }

    // MARK: - iCloud Section

    private var iCloudSection: some View {
        Section {
            HStack {
                Image(systemName: iCloudStatusIcon)
                    .foregroundColor(iCloudStatusColor)
                Text("iCloud Status")
                Spacer()
                Text(iCloudStatusText)
                    .foregroundColor(.secondary)
            }

            Button(action: {
                Task {
                    await dataManager.syncFromCloud()
                }
            }) {
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text("Sync Now")
                }
            }
            .disabled(cloudKitManager.iCloudStatus != .available || dataManager.isLoading)
        } header: {
            Text("iCloud Sync")
        } footer: {
            Text("Your workout data is automatically synced to iCloud when available.")
        }
    }

    private var iCloudStatusIcon: String {
        switch cloudKitManager.iCloudStatus {
        case .available:
            return "checkmark.icloud.fill"
        case .noAccount:
            return "xmark.icloud.fill"
        case .restricted, .couldNotDetermine, .temporarilyUnavailable:
            return "exclamationmark.icloud.fill"
        @unknown default:
            return "icloud.fill"
        }
    }

    private var iCloudStatusColor: Color {
        switch cloudKitManager.iCloudStatus {
        case .available:
            return .green
        case .noAccount:
            return .red
        case .restricted, .couldNotDetermine, .temporarilyUnavailable:
            return .orange
        @unknown default:
            return .gray
        }
    }

    private var iCloudStatusText: String {
        switch cloudKitManager.iCloudStatus {
        case .available:
            return "Connected"
        case .noAccount:
            return "Not Signed In"
        case .restricted:
            return "Restricted"
        case .couldNotDetermine:
            return "Checking..."
        case .temporarilyUnavailable:
            return "Temporarily Unavailable"
        @unknown default:
            return "Unknown"
        }
    }

    // MARK: - Danger Zone Section

    private var dangerZoneSection: some View {
        Section {
            Button(role: .destructive, action: {
                showDeleteConfirmation = true
            }) {
                HStack {
                    if isDeleting {
                        ProgressView()
                            .padding(.trailing, 4)
                    }
                    Image(systemName: "trash.fill")
                    Text("Delete All Data")
                }
            }
            .disabled(isDeleting)
        } header: {
            Text("Danger Zone")
        } footer: {
            Text("This will delete all workout data from this device and iCloud.")
        }
    }

    private func deleteAllData() {
        isDeleting = true
        Task {
            do {
                try await dataManager.deleteAllData()
                isDeleting = false
            } catch {
                deleteError = error.localizedDescription
                isDeleting = false
            }
        }
    }
}

// MARK: - Color Button

struct ColorButton: View {
    let color: CodableColor
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(color.color)
                .frame(width: 44, height: 44)
                .overlay(
                    Circle()
                        .stroke(Color.primary, lineWidth: isSelected ? 3 : 0)
                        .padding(2)
                )
                .overlay(
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .opacity(isSelected ? 1 : 0)
                )
                .shadow(color: color.color.opacity(0.4), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    SettingsView()
}
