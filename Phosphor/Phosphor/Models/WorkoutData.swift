import Foundation
import SwiftUI

struct MuscleGroupData: Codable, Identifiable {
    var id: String { muscleGroup.rawValue }
    let muscleGroup: MuscleGroup
    var lastTappedDate: Date?
    var tapCount: Int

    init(muscleGroup: MuscleGroup, lastTappedDate: Date? = nil, tapCount: Int = 0) {
        self.muscleGroup = muscleGroup
        self.lastTappedDate = lastTappedDate
        self.tapCount = tapCount
    }

    func intensity(cooldownDays: Double) -> Double {
        guard let lastTapped = lastTappedDate else { return 0 }
        let elapsed = Date().timeIntervalSince(lastTapped)
        let cooldownSeconds = cooldownDays * 24 * 60 * 60
        let remaining = max(0, 1 - (elapsed / cooldownSeconds))
        return remaining
    }

    /// Calculate intensity as it would have been at a specific reference date
    func intensity(cooldownDays: Double, asOf referenceDate: Date) -> Double {
        guard let lastTapped = lastTappedDate else { return 0 }
        // If the tap happened after the reference date, it wouldn't have existed yet
        if lastTapped > referenceDate { return 0 }
        let elapsed = referenceDate.timeIntervalSince(lastTapped)
        let cooldownSeconds = cooldownDays * 24 * 60 * 60
        let remaining = max(0, 1 - (elapsed / cooldownSeconds))
        return remaining
    }
}

enum Gender: String, Codable, CaseIterable {
    case male = "Male"
    case female = "Female"
}

enum AppearanceMode: String, Codable, CaseIterable {
    case light = "Light"
    case dark = "Dark"
    case system = "System"
}

struct UserSettings: Codable {
    var highlightColor: CodableColor
    var cooldownDays: Double
    var gender: Gender
    var appearanceMode: AppearanceMode

    // Computed property for backwards compatibility and convenience
    var darkMode: Bool {
        appearanceMode == .dark
    }

    init(highlightColor: CodableColor = CodableColor(color: .orange), cooldownDays: Double = 3.0, gender: Gender = .male, appearanceMode: AppearanceMode = .system) {
        self.highlightColor = highlightColor
        self.cooldownDays = cooldownDays
        self.gender = gender
        self.appearanceMode = appearanceMode
    }

    // Custom decoding to handle migration from old darkMode bool
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        highlightColor = try container.decode(CodableColor.self, forKey: .highlightColor)
        cooldownDays = try container.decode(Double.self, forKey: .cooldownDays)
        gender = try container.decode(Gender.self, forKey: .gender)

        // Try to decode new appearanceMode, fall back to old darkMode
        if let mode = try? container.decode(AppearanceMode.self, forKey: .appearanceMode) {
            appearanceMode = mode
        } else if let oldDarkMode = try? container.decode(Bool.self, forKey: .darkMode) {
            appearanceMode = oldDarkMode ? .dark : .light
        } else {
            appearanceMode = .system
        }
    }

    // Custom encoding (only encode stored properties)
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(highlightColor, forKey: .highlightColor)
        try container.encode(cooldownDays, forKey: .cooldownDays)
        try container.encode(gender, forKey: .gender)
        try container.encode(appearanceMode, forKey: .appearanceMode)
    }

    private enum CodingKeys: String, CodingKey {
        case highlightColor, cooldownDays, gender, appearanceMode, darkMode
    }
}

struct CodableColor: Codable {
    var red: Double
    var green: Double
    var blue: Double
    var opacity: Double

    init(color: Color) {
        // Default to orange
        self.red = 1.0
        self.green = 0.6
        self.blue = 0.0
        self.opacity = 1.0
    }

    init(red: Double, green: Double, blue: Double, opacity: Double = 1.0) {
        self.red = red
        self.green = green
        self.blue = blue
        self.opacity = opacity
    }

    var color: Color {
        Color(red: red, green: green, blue: blue, opacity: opacity)
    }

    static let presetColors: [CodableColor] = [
        CodableColor(red: 1.0, green: 0.6, blue: 0.0),      // Orange
        CodableColor(red: 1.0, green: 0.2, blue: 0.2),      // Red
        CodableColor(red: 0.0, green: 0.8, blue: 0.4),      // Green
        CodableColor(red: 0.2, green: 0.6, blue: 1.0),      // Blue
        CodableColor(red: 0.8, green: 0.2, blue: 0.8),      // Purple
        CodableColor(red: 1.0, green: 0.8, blue: 0.0),      // Yellow
        CodableColor(red: 0.0, green: 0.8, blue: 0.8),      // Cyan
        CodableColor(red: 1.0, green: 0.4, blue: 0.6),      // Pink
    ]
}

struct WorkoutSession: Codable, Identifiable {
    let id: UUID
    let muscleGroup: MuscleGroup
    let date: Date

    init(muscleGroup: MuscleGroup, date: Date = Date()) {
        self.id = UUID()
        self.muscleGroup = muscleGroup
        self.date = date
    }
}
