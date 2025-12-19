import Foundation
import CloudKit
import SwiftUI

@MainActor
class CloudKitManager: ObservableObject {
    static let shared = CloudKitManager()

    private let container: CKContainer
    private let privateDatabase: CKDatabase
    private let recordType = "WorkoutData"
    private let settingsRecordType = "UserSettings"

    @Published var iCloudStatus: CKAccountStatus = .couldNotDetermine
    @Published var isLoading = false
    @Published var errorMessage: String?

    private init() {
        container = CKContainer.default()
        privateDatabase = container.privateCloudDatabase
        checkAccountStatus()
    }

    func checkAccountStatus() {
        Task {
            do {
                let status = try await container.accountStatus()
                await MainActor.run {
                    self.iCloudStatus = status
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to check iCloud status: \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - Save Data

    func saveMuscleGroupData(_ data: [MuscleGroupData]) async throws {
        guard iCloudStatus == .available else {
            throw CloudKitError.iCloudNotAvailable
        }

        isLoading = true
        defer { isLoading = false }

        for muscleData in data {
            let recordID = CKRecord.ID(recordName: muscleData.muscleGroup.rawValue)
            let record = CKRecord(recordType: recordType, recordID: recordID)

            record["muscleGroup"] = muscleData.muscleGroup.rawValue
            record["tapCount"] = muscleData.tapCount
            if let lastTapped = muscleData.lastTappedDate {
                record["lastTappedDate"] = lastTapped
            }

            do {
                _ = try await privateDatabase.save(record)
            } catch let error as CKError where error.code == .serverRecordChanged {
                // Handle conflict by fetching and updating
                if let serverRecord = error.userInfo[CKRecordChangedErrorServerRecordKey] as? CKRecord {
                    serverRecord["tapCount"] = muscleData.tapCount
                    if let lastTapped = muscleData.lastTappedDate {
                        serverRecord["lastTappedDate"] = lastTapped
                    }
                    _ = try await privateDatabase.save(serverRecord)
                }
            }
        }
    }

    func saveSettings(_ settings: UserSettings) async throws {
        guard iCloudStatus == .available else {
            throw CloudKitError.iCloudNotAvailable
        }

        let recordID = CKRecord.ID(recordName: "userSettings")
        let record = CKRecord(recordType: settingsRecordType, recordID: recordID)

        record["highlightRed"] = settings.highlightColor.red
        record["highlightGreen"] = settings.highlightColor.green
        record["highlightBlue"] = settings.highlightColor.blue
        record["cooldownDays"] = settings.cooldownDays

        do {
            _ = try await privateDatabase.save(record)
        } catch let error as CKError where error.code == .serverRecordChanged {
            if let serverRecord = error.userInfo[CKRecordChangedErrorServerRecordKey] as? CKRecord {
                serverRecord["highlightRed"] = settings.highlightColor.red
                serverRecord["highlightGreen"] = settings.highlightColor.green
                serverRecord["highlightBlue"] = settings.highlightColor.blue
                serverRecord["cooldownDays"] = settings.cooldownDays
                _ = try await privateDatabase.save(serverRecord)
            }
        }
    }

    // MARK: - Fetch Data

    func fetchMuscleGroupData() async throws -> [MuscleGroupData] {
        guard iCloudStatus == .available else {
            throw CloudKitError.iCloudNotAvailable
        }

        isLoading = true
        defer { isLoading = false }

        let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
        let (results, _) = try await privateDatabase.records(matching: query)

        var muscleData: [MuscleGroupData] = []

        for (_, result) in results {
            if case .success(let record) = result {
                if let muscleGroupName = record["muscleGroup"] as? String,
                   let muscleGroup = MuscleGroup(rawValue: muscleGroupName) {
                    let tapCount = record["tapCount"] as? Int ?? 0
                    let lastTapped = record["lastTappedDate"] as? Date

                    muscleData.append(MuscleGroupData(
                        muscleGroup: muscleGroup,
                        lastTappedDate: lastTapped,
                        tapCount: tapCount
                    ))
                }
            }
        }

        return muscleData
    }

    func fetchSettings() async throws -> UserSettings? {
        guard iCloudStatus == .available else {
            throw CloudKitError.iCloudNotAvailable
        }

        let recordID = CKRecord.ID(recordName: "userSettings")

        do {
            let record = try await privateDatabase.record(for: recordID)

            let red = record["highlightRed"] as? Double ?? 1.0
            let green = record["highlightGreen"] as? Double ?? 0.6
            let blue = record["highlightBlue"] as? Double ?? 0.0
            let cooldownDays = record["cooldownDays"] as? Double ?? 3.0

            return UserSettings(
                highlightColor: CodableColor(red: red, green: green, blue: blue),
                cooldownDays: cooldownDays
            )
        } catch let error as CKError where error.code == .unknownItem {
            return nil
        }
    }

    // MARK: - Delete Account

    func deleteAllUserData() async throws {
        guard iCloudStatus == .available else {
            throw CloudKitError.iCloudNotAvailable
        }

        isLoading = true
        defer { isLoading = false }

        // Delete all muscle group records
        let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
        let (results, _) = try await privateDatabase.records(matching: query)

        for (recordID, _) in results {
            try await privateDatabase.deleteRecord(withID: recordID)
        }

        // Delete settings
        let settingsRecordID = CKRecord.ID(recordName: "userSettings")
        do {
            try await privateDatabase.deleteRecord(withID: settingsRecordID)
        } catch let error as CKError where error.code == .unknownItem {
            // Settings don't exist, that's fine
        }
    }

    enum CloudKitError: LocalizedError {
        case iCloudNotAvailable

        var errorDescription: String? {
            switch self {
            case .iCloudNotAvailable:
                return "iCloud is not available. Please sign in to iCloud in Settings."
            }
        }
    }
}
