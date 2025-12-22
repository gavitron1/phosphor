import SwiftUI

struct SettingsView: View {
    @ObservedObject var dataManager = DataManager.shared
    @ObservedObject var cloudKitManager = CloudKitManager.shared
    @ObservedObject var notificationManager = NotificationManager.shared

    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var deleteError: String?

    var body: some View {
        NavigationStack {
            Form {
                genderSection

                appearanceSection

                notificationSection

                syncSection

                iCloudSection

                dangerZoneSection
            }
            .navigationTitle("Settings")
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
            Picker("Mode", selection: Binding(
                get: { dataManager.settings.appearanceMode },
                set: { dataManager.updateAppearanceMode($0) }
            )) {
                ForEach(AppearanceMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            // Color picker grid
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
            .padding(.vertical, 8)
        } header: {
            Text("Appearance")
        }
    }

    // MARK: - Notification Section

    private var notificationSection: some View {
        Section {
            HStack {
                Image(systemName: notificationManager.isAuthorized ? "bell.badge.fill" : "bell.slash.fill")
                    .foregroundColor(notificationManager.isAuthorized ? .green : .secondary)
                Text("Notifications")
                Spacer()
                Text(notificationStatusText)
                    .foregroundColor(.secondary)
            }

            if !notificationManager.isAuthorized {
                Button(action: {
                    Task {
                        await notificationManager.requestAuthorization()
                    }
                }) {
                    HStack {
                        Image(systemName: "bell.badge")
                        Text("Enable Notifications")
                    }
                }
            }
        } header: {
            Text("Notifications")
        } footer: {
            Text("Get notified when muscle groups are about to reach full recovery.")
        }
    }

    private var notificationStatusText: String {
        switch notificationManager.authorizationStatus {
        case .authorized:
            return "Enabled"
        case .denied:
            return "Denied"
        case .provisional:
            return "Provisional"
        case .ephemeral:
            return "Ephemeral"
        case .notDetermined:
            return "Not Set"
        @unknown default:
            return "Unknown"
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

    private func isColorSelected(_ color: CodableColor) -> Bool {
        let current = dataManager.settings.highlightColor
        return abs(current.red - color.red) < 0.01 &&
               abs(current.green - color.green) < 0.01 &&
               abs(current.blue - color.blue) < 0.01
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
