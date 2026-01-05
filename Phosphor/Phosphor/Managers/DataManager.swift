import Foundation
import SwiftUI
import Combine

@MainActor
class DataManager: ObservableObject {
    static let shared = DataManager()

    @Published var muscleGroupData: [MuscleGroup: MuscleGroupData] = [:]
    @Published var settings: UserSettings = UserSettings()
    @Published var weightHistory: [WeightEntry] = []
    @Published var exerciseHistory: [ExerciseRecord] = []
    @Published var isLoading = false
    @Published var syncError: String?

    private let muscleDataKey = "muscleGroupData"
    private let settingsKey = "userSettings"
    private let weightHistoryKey = "weightHistory"
    private let exerciseHistoryKey = "exerciseHistory"
    private let cloudKitManager = CloudKitManager.shared

    private var syncTimer: Timer?
    private var debouncedSyncTask: Task<Void, Never>?
    private var debouncedSettingsSyncTask: Task<Void, Never>?

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

        // Load weight history
        if let data = UserDefaults.standard.data(forKey: weightHistoryKey),
           let decoded = try? JSONDecoder().decode([WeightEntry].self, from: data) {
            weightHistory = decoded
        }

        // Load exercise history
        if let data = UserDefaults.standard.data(forKey: exerciseHistoryKey),
           let decoded = try? JSONDecoder().decode([ExerciseRecord].self, from: data) {
            exerciseHistory = decoded
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

        if let encoded = try? JSONEncoder().encode(weightHistory) {
            UserDefaults.standard.set(encoded, forKey: weightHistoryKey)
        }

        if let encoded = try? JSONEncoder().encode(exerciseHistory) {
            UserDefaults.standard.set(encoded, forKey: exerciseHistoryKey)
        }
    }

    // MARK: - Muscle Group Actions

    /// Tap a muscle group. If tapped again within 10 seconds, undo the tap.
    /// Returns true if the tap was recorded, false if it was undone, nil if disabled.
    @discardableResult
    func tapMuscleGroup(_ group: MuscleGroup) -> Bool? {
        var data = muscleGroupData[group] ?? MuscleGroupData(muscleGroup: group)

        // Check if muscle group is enabled
        guard data.isEnabled else { return nil }

        // Check if this is an undo (tapped again within 10 seconds)
        if let lastTapped = data.lastTappedDate {
            let elapsed = Date().timeIntervalSince(lastTapped)
            if elapsed < 10 {
                // Undo: restore the previous date and decrement count
                data = MuscleGroupData(
                    muscleGroup: group,
                    lastTappedDate: data.previousTappedDate,  // Restore previous date
                    previousTappedDate: nil,  // Clear the undo state
                    tapCount: max(0, data.tapCount - 1),
                    cooldownDays: data.cooldownDays,
                    isEnabled: data.isEnabled
                )
                muscleGroupData[group] = data
                saveLocalData()
                debouncedSyncToCloud()
                return false // Tap was undone
            }
        }

        // Normal tap: save current date as previous, then record new tap
        data = MuscleGroupData(
            muscleGroup: group,
            lastTappedDate: Date(),
            previousTappedDate: data.lastTappedDate,  // Save old date for potential undo
            tapCount: data.tapCount + 1,
            cooldownDays: data.cooldownDays,
            isEnabled: data.isEnabled
        )
        muscleGroupData[group] = data
        saveLocalData()
        debouncedSyncToCloud()
        return true // Tap was recorded
    }

    /// Debounced sync - waits 2 seconds after last call before actually syncing
    private func debouncedSyncToCloud() {
        debouncedSyncTask?.cancel()
        debouncedSyncTask = Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)  // 2 seconds
            if !Task.isCancelled {
                await syncToCloud()
            }
        }
    }

    /// Debounced settings sync - waits 1 second after last call before syncing
    private func debouncedSyncSettingsToCloud() {
        debouncedSettingsSyncTask?.cancel()
        debouncedSettingsSyncTask = Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000)  // 1 second
            if !Task.isCancelled {
                await syncSettingsToCloud()
            }
        }
    }

    func getIntensity(for group: MuscleGroup) -> Double {
        guard let data = muscleGroupData[group] else { return 0 }
        return data.intensity()  // Uses per-muscle-group cooldown
    }

    func getIntensity(for group: MuscleGroup, asOf date: Date) -> Double {
        guard let data = muscleGroupData[group] else { return 0 }
        return data.intensity(asOf: date)  // Uses per-muscle-group cooldown
    }

    func isEnabled(for group: MuscleGroup) -> Bool {
        muscleGroupData[group]?.isEnabled ?? true
    }

    func getCooldownDays(for group: MuscleGroup) -> Double {
        muscleGroupData[group]?.cooldownDays ?? 3.0
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

    // MARK: - Per-Muscle-Group Settings

    func updateMuscleGroupEnabled(_ group: MuscleGroup, enabled: Bool) {
        guard var data = muscleGroupData[group] else { return }
        data = MuscleGroupData(
            muscleGroup: group,
            lastTappedDate: data.lastTappedDate,
            previousTappedDate: data.previousTappedDate,
            tapCount: data.tapCount,
            cooldownDays: data.cooldownDays,
            isEnabled: enabled
        )
        muscleGroupData[group] = data
        saveLocalData()
        debouncedSyncToCloud()
    }

    func updateMuscleGroupCooldown(_ group: MuscleGroup, days: Double) {
        guard var data = muscleGroupData[group] else { return }
        data = MuscleGroupData(
            muscleGroup: group,
            lastTappedDate: data.lastTappedDate,
            previousTappedDate: data.previousTappedDate,
            tapCount: data.tapCount,
            cooldownDays: days,
            isEnabled: data.isEnabled
        )
        muscleGroupData[group] = data
        saveLocalData()
        debouncedSyncToCloud()
    }

    // MARK: - Settings

    func updateHighlightColor(_ color: CodableColor) {
        settings.highlightColor = color
        saveLocalData()
        debouncedSyncSettingsToCloud()
    }

    func updateCooldownDays(_ days: Double) {
        settings.cooldownDays = days
        saveLocalData()
        debouncedSyncSettingsToCloud()
    }

    func updateGender(_ gender: Gender) {
        settings.gender = gender
        saveLocalData()
        debouncedSyncSettingsToCloud()
    }

    func updateAppearanceMode(_ mode: AppearanceMode) {
        settings.appearanceMode = mode
        saveLocalData()
        debouncedSyncSettingsToCloud()
    }

    func updateWeight(_ weight: Double?) {
        objectWillChange.send()  // Ensure view updates
        settings.weight = weight

        // Also log to weight history (one entry per day)
        if let weight = weight {
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())

            // Remove any existing entry for today
            weightHistory.removeAll { entry in
                calendar.startOfDay(for: entry.date) == today
            }

            // Add the new entry
            let entry = WeightEntry(weight: weight)
            weightHistory.append(entry)
        }

        saveLocalData()
        debouncedSyncSettingsToCloud()
    }

    /// Returns weight history with only one entry per day (the last one for each day)
    func getDailyWeightHistory() -> [WeightEntry] {
        let calendar = Calendar.current
        var dailyEntries: [Date: WeightEntry] = [:]

        for entry in weightHistory {
            let dayStart = calendar.startOfDay(for: entry.date)
            // Always take the latest entry for each day
            if let existing = dailyEntries[dayStart] {
                if entry.date > existing.date {
                    dailyEntries[dayStart] = entry
                }
            } else {
                dailyEntries[dayStart] = entry
            }
        }

        // Sort by date and return
        return dailyEntries.values.sorted { $0.date < $1.date }
    }

    func updateWeightUnit(_ unit: WeightUnit) {
        let oldUnit = settings.weightUnit
        guard oldUnit != unit else { return }

        // Convert current weight
        if let currentWeight = settings.weight {
            settings.weight = convertWeight(currentWeight, from: oldUnit, to: unit)
        }

        // Convert weight history
        weightHistory = weightHistory.map { entry in
            WeightEntry(
                weight: convertWeight(entry.weight, from: oldUnit, to: unit),
                date: entry.date
            )
        }

        settings.weightUnit = unit
        saveLocalData()
        debouncedSyncSettingsToCloud()
    }

    private func convertWeight(_ weight: Double, from: WeightUnit, to: WeightUnit) -> Double {
        if from == to { return weight }
        if from == .pounds && to == .kilograms {
            return weight * 0.453592
        } else {
            return weight * 2.20462
        }
    }

    func getWeight(for date: Date) -> Double? {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date

        // Find the last weight entry for this day
        let entriesForDay = weightHistory.filter { entry in
            entry.date >= startOfDay && entry.date < endOfDay
        }

        return entriesForDay.last?.weight
    }

    func updateUseUnifiedCooldown(_ useUnified: Bool) {
        settings.useUnifiedCooldown = useUnified
        saveLocalData()
        debouncedSyncSettingsToCloud()
    }

    // MARK: - Exercise History

    func recordExercise(_ exercise: Exercise) {
        let record = ExerciseRecord(exercise: exercise)
        exerciseHistory.append(record)
        saveLocalData()
    }

    /// Get the 3 most recently used exercises for a muscle group
    func getRecentExercises(for muscleGroup: MuscleGroup) -> [Exercise] {
        // Filter exercises that work this muscle group, get unique by exerciseId, take last 3
        var seen = Set<String>()
        var recent: [String] = []

        for record in exerciseHistory.reversed() {
            if record.muscleGroups.contains(muscleGroup) && !seen.contains(record.exerciseId) {
                seen.insert(record.exerciseId)
                recent.append(record.exerciseId)
                if recent.count >= 3 {
                    break
                }
            }
        }

        // Convert IDs back to Exercise objects
        return recent.compactMap { id in
            ExerciseDatabase.exercises.first { $0.id == id }
        }
    }

    /// Get exercises done on a specific date
    func getExercises(for date: Date) -> [ExerciseRecord] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date

        return exerciseHistory.filter { record in
            record.date >= startOfDay && record.date < endOfDay
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
