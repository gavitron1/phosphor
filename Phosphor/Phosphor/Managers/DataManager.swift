import Foundation
import SwiftUI
import Combine

@MainActor
class DataManager: ObservableObject {
    static let shared = DataManager()

    @Published var muscleGroupData: [MuscleGroup: MuscleGroupData] = [:]
    @Published var settings: UserSettings = UserSettings()
    @Published var isLoading = false
    @Published var syncError: String?

    private let muscleDataKey = "muscleGroupData"
    private let settingsKey = "userSettings"
    private let cloudKitManager = CloudKitManager.shared

    private var syncTimer: Timer?

    private init() {
        loadLocalData()
        startIntensityUpdateTimer()
    }

    // MARK: - Local Storage

    private func loadLocalData() {
        // Load muscle group data
        if let data = UserDefaults.standard.data(forKey: muscleDataKey),
           let decoded = try? JSONDecoder().decode([MuscleGroupData].self, from: data) {
            for item in decoded {
                muscleGroupData[item.muscleGroup] = item
            }
        }

        // Initialize missing muscle groups
        for group in MuscleGroup.allCases {
            if muscleGroupData[group] == nil {
                muscleGroupData[group] = MuscleGroupData(muscleGroup: group)
            }
        }

        // Load settings
        if let data = UserDefaults.standard.data(forKey: settingsKey),
           let decoded = try? JSONDecoder().decode(UserSettings.self, from: data) {
            settings = decoded
        }
    }

    private func saveLocalData() {
        let dataArray = Array(muscleGroupData.values)
        if let encoded = try? JSONEncoder().encode(dataArray) {
            UserDefaults.standard.set(encoded, forKey: muscleDataKey)
        }

        if let encoded = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(encoded, forKey: settingsKey)
        }
    }

    // MARK: - Muscle Group Actions

    func tapMuscleGroup(_ group: MuscleGroup) {
        var data = muscleGroupData[group] ?? MuscleGroupData(muscleGroup: group)
        data = MuscleGroupData(
            muscleGroup: group,
            lastTappedDate: Date(),
            tapCount: data.tapCount + 1
        )
        muscleGroupData[group] = data
        saveLocalData()

        // Sync to iCloud
        Task {
            await syncToCloud()
        }
    }

    func getIntensity(for group: MuscleGroup) -> Double {
        guard let data = muscleGroupData[group] else { return 0 }
        return data.intensity(cooldownDays: settings.cooldownDays)
    }

    func getIntensity(for group: MuscleGroup, asOf date: Date) -> Double {
        guard let data = muscleGroupData[group] else { return 0 }
        return data.intensity(cooldownDays: settings.cooldownDays, asOf: date)
    }

    func getTapCount(for group: MuscleGroup) -> Int {
        muscleGroupData[group]?.tapCount ?? 0
    }

    func getSortedMuscleGroups() -> [MuscleGroupData] {
        Array(muscleGroupData.values)
            .sorted { $0.tapCount > $1.tapCount }
    }

    func getMaxTapCount() -> Int {
        muscleGroupData.values.map { $0.tapCount }.max() ?? 1
    }

    // MARK: - Settings

    func updateHighlightColor(_ color: CodableColor) {
        settings.highlightColor = color
        saveLocalData()

        Task {
            await syncSettingsToCloud()
        }
    }

    func updateCooldownDays(_ days: Double) {
        settings.cooldownDays = days
        saveLocalData()

        Task {
            await syncSettingsToCloud()
        }
    }

    func updateGender(_ gender: Gender) {
        settings.gender = gender
        saveLocalData()

        Task {
            await syncSettingsToCloud()
        }
    }

    func updateDarkMode(_ enabled: Bool) {
        settings.darkMode = enabled
        saveLocalData()

        Task {
            await syncSettingsToCloud()
        }
    }

    // MARK: - iCloud Sync

    func syncFromCloud() async {
        isLoading = true
        defer { isLoading = false }

        do {
            // Fetch muscle data
            let cloudData = try await cloudKitManager.fetchMuscleGroupData()
            for item in cloudData {
                // Merge: keep the higher tap count and more recent date
                if let existing = muscleGroupData[item.muscleGroup] {
                    let mergedTapCount = max(existing.tapCount, item.tapCount)
                    var mergedDate = existing.lastTappedDate

                    if let cloudDate = item.lastTappedDate {
                        if let localDate = existing.lastTappedDate {
                            mergedDate = max(localDate, cloudDate)
                        } else {
                            mergedDate = cloudDate
                        }
                    }

                    muscleGroupData[item.muscleGroup] = MuscleGroupData(
                        muscleGroup: item.muscleGroup,
                        lastTappedDate: mergedDate,
                        tapCount: mergedTapCount
                    )
                } else {
                    muscleGroupData[item.muscleGroup] = item
                }
            }

            // Fetch settings
            if let cloudSettings = try await cloudKitManager.fetchSettings() {
                settings = cloudSettings
            }

            saveLocalData()
            syncError = nil
        } catch {
            syncError = error.localizedDescription
        }
    }

    func syncToCloud() async {
        do {
            try await cloudKitManager.saveMuscleGroupData(Array(muscleGroupData.values))
            syncError = nil
        } catch {
            syncError = error.localizedDescription
        }
    }

    func syncSettingsToCloud() async {
        do {
            try await cloudKitManager.saveSettings(settings)
            syncError = nil
        } catch {
            syncError = error.localizedDescription
        }
    }

    // MARK: - Delete Account

    func deleteAllData() async throws {
        // Delete from iCloud
        try await cloudKitManager.deleteAllUserData()

        // Clear local data
        muscleGroupData = [:]
        for group in MuscleGroup.allCases {
            muscleGroupData[group] = MuscleGroupData(muscleGroup: group)
        }
        settings = UserSettings()

        // Clear UserDefaults
        UserDefaults.standard.removeObject(forKey: muscleDataKey)
        UserDefaults.standard.removeObject(forKey: settingsKey)

        saveLocalData()
    }

    // MARK: - Timer for UI Updates

    private func startIntensityUpdateTimer() {
        // Update every second to refresh intensity values for smooth animation
        syncTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.objectWillChange.send()
            }
        }
    }
}
