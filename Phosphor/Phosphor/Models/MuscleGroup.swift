import Foundation

enum MuscleGroup: String, CaseIterable, Codable, Identifiable {
    case chest = "Chest"
    case back = "Back"
    case shoulders = "Shoulders"
    case biceps = "Biceps"
    case triceps = "Triceps"
    case forearms = "Forearms"
    case abs = "Abs"
    case obliques = "Obliques"
    case lowerBack = "Lower Back"
    case glutes = "Glutes"
    case quadriceps = "Quadriceps"
    case hamstrings = "Hamstrings"
    case calves = "Calves"
    case traps = "Traps"
    case lats = "Lats"
    case hipFlexors = "Hip Flexors"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .chest: return "heart.fill"
        case .back: return "figure.stand"
        case .shoulders: return "figure.arms.open"
        case .biceps: return "figure.strengthtraining.traditional"
        case .triceps: return "figure.strengthtraining.functional"
        case .forearms: return "hand.raised.fill"
        case .abs: return "figure.core.training"
        case .obliques: return "figure.flexibility"
        case .lowerBack: return "figure.walk"
        case .glutes: return "figure.run"
        case .quadriceps: return "figure.hiking"
        case .hamstrings: return "figure.step.training"
        case .calves: return "figure.jumprope"
        case .traps: return "figure.climbing"
        case .lats: return "figure.pool.swim"
        case .hipFlexors: return "figure.cooldown"
        }
    }
}
