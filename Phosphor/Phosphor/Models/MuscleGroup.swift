import Foundation

enum MuscleGroup: String, CaseIterable, Codable, Identifiable {
    // Front muscles
    case abs = "Abs"
    case biceps = "Biceps"
    case chest = "Chest"
    case neck = "Neck"
    case obliques = "Obliques"
    case shoulders = "Shoulders"
    case thighs = "Thighs"
    case traps = "Traps"
    case forearms = "Forearms"
    case calves = "Calves"
    case innerthigh = "Inner Thigh"
    case outerthigh = "Outer Thigh"
    case wrists = "Wrists"
    case heart = "Cardio"

    // Back muscles
    case glutes = "Glutes"
    case hamstrings = "Hamstrings"
    case lats = "Lats"
    case lowerback = "Lower Back"
    case outerback = "Upper Back"
    case triceps = "Triceps"

    var id: String { rawValue }

    // Image name for front view (male)
    func frontImageName(for gender: Gender) -> String? {
        let prefix = gender == .male ? "male-front" : "female-front"
        switch self {
        case .abs: return "\(prefix)-abs"
        case .biceps: return "\(prefix)-biceps"
        case .chest: return "\(prefix)-chest"
        case .neck: return "\(prefix)-neck"
        case .obliques: return "\(prefix)-obliques"
        case .shoulders: return "\(prefix)-shoulders"
        case .thighs: return "\(prefix)-thighs"
        case .traps: return "\(prefix)-traps"
        case .forearms: return "\(prefix)-forearms"
        case .calves: return "\(prefix)-calves"
        case .innerthigh: return "\(prefix)-innerthigh"
        case .outerthigh: return "\(prefix)-outerthigh"
        case .wrists: return "\(prefix)-wrists"
        case .heart: return "\(prefix)-heart"
        default: return nil
        }
    }

    // Image name for back view
    func backImageName(for gender: Gender) -> String? {
        let prefix = gender == .male ? "male-back" : "female-back"
        switch self {
        case .calves: return "\(prefix)-calves"
        case .forearms: return "\(prefix)-forearms"
        case .glutes: return "\(prefix)-glutes"
        case .hamstrings: return "\(prefix)-hamstrings"
        case .innerthigh: return "\(prefix)-innerthigh"
        case .lats: return "\(prefix)-lats"
        case .lowerback: return "\(prefix)-lowerback"
        case .neck: return "\(prefix)-neck"
        case .obliques: return "\(prefix)-obliques"
        case .outerback: return "\(prefix)-outerback"
        case .outerthigh: return "\(prefix)-outerthigh"
        case .shoulders: return "\(prefix)-shoulders"
        case .traps: return "\(prefix)-traps"
        case .triceps: return "\(prefix)-triceps"
        case .wrists: return "\(prefix)-wrists"
        default: return nil
        }
    }

    // All muscle groups visible in front view
    static var frontMuscles: [MuscleGroup] {
        [.abs, .biceps, .chest, .neck, .obliques, .shoulders, .thighs, .traps, .forearms, .calves, .innerthigh, .outerthigh, .wrists, .heart]
    }

    // All muscle groups visible in back view
    static var backMuscles: [MuscleGroup] {
        [.calves, .forearms, .glutes, .hamstrings, .innerthigh, .lats, .lowerback, .neck, .obliques, .outerback, .outerthigh, .shoulders, .traps, .triceps, .wrists]
    }

    var systemImage: String {
        switch self {
        case .chest: return "heart.fill"
        case .shoulders: return "figure.arms.open"
        case .biceps: return "figure.strengthtraining.traditional"
        case .triceps: return "figure.strengthtraining.functional"
        case .forearms: return "hand.raised.fill"
        case .abs: return "figure.core.training"
        case .obliques: return "figure.flexibility"
        case .lowerback: return "figure.walk"
        case .glutes: return "figure.run"
        case .thighs: return "figure.hiking"
        case .hamstrings: return "figure.step.training"
        case .calves: return "figure.jumprope"
        case .traps: return "figure.climbing"
        case .lats: return "figure.pool.swim"
        case .neck: return "head.profile.arrow.forward.and.visionpro"
        case .innerthigh: return "figure.gymnastics"
        case .outerthigh: return "figure.hiking"
        case .outerback: return "figure.mixed.cardio"
        case .wrists: return "hand.point.up"
        case .heart: return "heart.circle.fill"
        }
    }
}
