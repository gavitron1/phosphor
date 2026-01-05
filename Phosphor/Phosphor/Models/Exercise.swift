import Foundation

struct Exercise: Identifiable, Codable {
    let id: String
    let name: String
    let muscleWork: [MuscleGroup: Double]  // Muscle group -> percentage (0.0 to 1.0)
    let category: ExerciseCategory

    init(id: String = UUID().uuidString, name: String, muscleWork: [MuscleGroup: Double], category: ExerciseCategory) {
        self.id = id
        self.name = name
        self.muscleWork = muscleWork
        self.category = category
    }

    /// Convenience initializer with all muscles at 100%
    init(id: String = UUID().uuidString, name: String, muscleGroups: [MuscleGroup], category: ExerciseCategory) {
        self.id = id
        self.name = name
        self.muscleWork = Dictionary(uniqueKeysWithValues: muscleGroups.map { ($0, 1.0) })
        self.category = category
    }

    /// Returns all muscle groups worked by this exercise
    var muscleGroups: [MuscleGroup] {
        Array(muscleWork.keys)
    }

    /// Returns the primary muscle group (highest percentage)
    var primaryMuscle: MuscleGroup? {
        muscleWork.max(by: { $0.value < $1.value })?.key
    }

    /// Get the work percentage for a specific muscle (0.0 to 1.0)
    func workPercentage(for muscle: MuscleGroup) -> Double {
        muscleWork[muscle] ?? 0.0
    }
}

enum ExerciseCategory: String, Codable, CaseIterable {
    case chest = "Chest"
    case back = "Back"
    case shoulders = "Shoulders"
    case arms = "Arms"
    case legs = "Legs"
    case core = "Core"
    case fullBody = "Full Body"
    case cardio = "Cardio"
}

// MARK: - Exercise Database

struct ExerciseDatabase {
    static let exercises: [Exercise] = [
        // CHEST EXERCISES
        Exercise(id: "bench-press", name: "Bench Press", muscleGroups: [.chest, .triceps, .shoulders], category: .chest),
        Exercise(id: "incline-bench-press", name: "Incline Bench Press", muscleGroups: [.chest, .shoulders, .triceps], category: .chest),
        Exercise(id: "decline-bench-press", name: "Decline Bench Press", muscleGroups: [.chest, .triceps], category: .chest),
        Exercise(id: "dumbbell-flyes", name: "Dumbbell Flyes", muscleGroups: [.chest, .shoulders], category: .chest),
        Exercise(id: "cable-crossover", name: "Cable Crossover", muscleGroups: [.chest], category: .chest),
        Exercise(id: "push-ups", name: "Push-Ups", muscleGroups: [.chest, .triceps, .shoulders, .abs], category: .chest),
        Exercise(id: "chest-dips", name: "Chest Dips", muscleGroups: [.chest, .triceps, .shoulders], category: .chest),
        Exercise(id: "dumbbell-press", name: "Dumbbell Press", muscleGroups: [.chest, .triceps, .shoulders], category: .chest),
        Exercise(id: "machine-chest-press", name: "Machine Chest Press", muscleGroups: [.chest, .triceps], category: .chest),
        Exercise(id: "pec-deck", name: "Pec Deck", muscleGroups: [.chest], category: .chest),

        // BACK EXERCISES
        Exercise(id: "deadlift", name: "Deadlift", muscleGroups: [.lowerback, .glutes, .hamstrings, .traps, .lats], category: .back),
        Exercise(id: "barbell-row", name: "Barbell Row", muscleGroups: [.lats, .outerback, .biceps, .traps], category: .back),
        Exercise(id: "pull-ups", name: "Pull-Ups", muscleGroups: [.lats, .biceps, .outerback, .forearms], category: .back),
        Exercise(id: "chin-ups", name: "Chin-Ups", muscleGroups: [.lats, .biceps, .outerback], category: .back),
        Exercise(id: "lat-pulldown", name: "Lat Pulldown", muscleGroups: [.lats, .biceps, .outerback], category: .back),
        Exercise(id: "seated-cable-row", name: "Seated Cable Row", muscleGroups: [.lats, .outerback, .biceps, .traps], category: .back),
        Exercise(id: "single-arm-row", name: "Single Arm Dumbbell Row", muscleGroups: [.lats, .outerback, .biceps], category: .back),
        Exercise(id: "t-bar-row", name: "T-Bar Row", muscleGroups: [.lats, .outerback, .traps, .biceps], category: .back),
        Exercise(id: "face-pulls", name: "Face Pulls", muscleGroups: [.outerback, .shoulders, .traps], category: .back),
        Exercise(id: "hyperextensions", name: "Hyperextensions", muscleGroups: [.lowerback, .glutes, .hamstrings], category: .back),
        Exercise(id: "good-mornings", name: "Good Mornings", muscleGroups: [.lowerback, .hamstrings, .glutes], category: .back),
        
        // BACK EXERCISES (Additions)
        Exercise(id: "assisted-pull-ups", name: "Assisted Pull-Ups", muscleGroups: [.lats, .biceps, .outerback, .forearms], category: .back),
        Exercise(id: "inverted-row", name: "Inverted Row", muscleGroups: [.outerback, .lats, .biceps, .forearms], category: .back),

        Exercise(id: "chest-supported-row", name: "Chest-Supported Row", muscleGroups: [.outerback, .lats, .traps, .biceps], category: .back),
        Exercise(id: "machine-row", name: "Machine Row", muscleGroups: [.lats, .outerback, .biceps, .traps], category: .back),

        Exercise(id: "pendlay-row", name: "Pendlay Row", muscleGroups: [.lats, .outerback, .traps, .lowerback, .biceps], category: .back),

        Exercise(id: "straight-arm-pulldown", name: "Straight-Arm Pulldown", muscleGroups: [.lats, .outerback], category: .back),
        Exercise(id: "cable-pullover", name: "Cable Pullover", muscleGroups: [.lats, .outerback], category: .back),

        Exercise(id: "rack-pull", name: "Rack Pull", muscleGroups: [.lowerback, .traps, .glutes, .hamstrings], category: .back),


        // SHOULDER EXERCISES
        Exercise(id: "overhead-press", name: "Overhead Press", muscleGroups: [.shoulders, .triceps, .traps], category: .shoulders),
        Exercise(id: "military-press", name: "Military Press", muscleGroups: [.shoulders, .triceps, .traps], category: .shoulders),
        Exercise(id: "arnold-press", name: "Arnold Press", muscleGroups: [.shoulders, .triceps], category: .shoulders),
        Exercise(id: "lateral-raises", name: "Lateral Raises", muscleGroups: [.shoulders], category: .shoulders),
        Exercise(id: "front-raises", name: "Front Raises", muscleGroups: [.shoulders, .chest], category: .shoulders),
        Exercise(id: "rear-delt-flyes", name: "Rear Delt Flyes", muscleGroups: [.shoulders, .outerback], category: .shoulders),
        Exercise(id: "upright-rows", name: "Upright Rows", muscleGroups: [.shoulders, .traps], category: .shoulders),
        Exercise(id: "shrugs", name: "Shrugs", muscleGroups: [.traps, .shoulders], category: .shoulders),
        Exercise(id: "dumbbell-shoulder-press", name: "Dumbbell Shoulder Press", muscleGroups: [.shoulders, .triceps], category: .shoulders),

        // SHOULDER EXERCISES (Additions)
        Exercise(id: "seated-dumbbell-shoulder-press", name: "Seated Dumbbell Shoulder Press", muscleGroups: [.shoulders, .triceps], category: .shoulders),
        Exercise(id: "machine-shoulder-press", name: "Machine Shoulder Press", muscleGroups: [.shoulders, .triceps], category: .shoulders),

        Exercise(id: "cable-lateral-raise", name: "Cable Lateral Raise", muscleGroups: [.shoulders], category: .shoulders),
        Exercise(id: "cable-front-raise", name: "Cable Front Raise", muscleGroups: [.shoulders, .chest], category: .shoulders),

        Exercise(id: "reverse-pec-deck", name: "Reverse Pec Deck", muscleGroups: [.shoulders, .outerback], category: .shoulders),
        Exercise(id: "y-raise", name: "Y-Raise", muscleGroups: [.shoulders, .outerback], category: .shoulders),

        Exercise(id: "cuban-press", name: "Cuban Press", muscleGroups: [.shoulders, .traps], category: .shoulders),

        // ARM EXERCISES - BICEPS
        Exercise(id: "barbell-curl", name: "Barbell Curl", muscleGroups: [.biceps, .forearms], category: .arms),
        Exercise(id: "dumbbell-curl", name: "Dumbbell Curl", muscleGroups: [.biceps, .forearms], category: .arms),
        Exercise(id: "hammer-curl", name: "Hammer Curl", muscleGroups: [.biceps, .forearms], category: .arms),
        Exercise(id: "preacher-curl", name: "Preacher Curl", muscleGroups: [.biceps], category: .arms),
        Exercise(id: "concentration-curl", name: "Concentration Curl", muscleGroups: [.biceps], category: .arms),
        Exercise(id: "cable-curl", name: "Cable Curl", muscleGroups: [.biceps, .forearms], category: .arms),
        Exercise(id: "incline-dumbbell-curl", name: "Incline Dumbbell Curl", muscleGroups: [.biceps], category: .arms),
        
        // ARM EXERCISES - BICEPS (Additions)
        Exercise(id: "ez-bar-curl", name: "EZ-Bar Curl", muscleGroups: [.biceps, .forearms], category: .arms),
        Exercise(id: "reverse-curl", name: "Reverse Curl", muscleGroups: [.biceps, .forearms], category: .arms),
        Exercise(id: "zottman-curl", name: "Zottman Curl", muscleGroups: [.biceps, .forearms], category: .arms),
        Exercise(id: "spider-curl", name: "Spider Curl", muscleGroups: [.biceps], category: .arms),
        Exercise(id: "drag-curl", name: "Drag Curl", muscleGroups: [.biceps], category: .arms),
        Exercise(id: "cross-body-hammer-curl", name: "Cross-Body Hammer Curl", muscleGroups: [.biceps, .forearms], category: .arms),
        Exercise(id: "machine-bicep-curl", name: "Machine Bicep Curl", muscleGroups: [.biceps, .forearms], category: .arms),

        // ARM EXERCISES - FOREARMS/GRIP (Additions)
        Exercise(id: "dead-hang", name: "Dead Hang", muscleGroups: [.forearms, .shoulders], category: .arms),
        Exercise(id: "plate-pinch-hold", name: "Plate Pinch Hold", muscleGroups: [.forearms, .wrists], category: .arms),
        Exercise(id: "wrist-roller", name: "Wrist Roller", muscleGroups: [.forearms, .wrists], category: .arms),
        Exercise(id: "behind-the-back-wrist-curl", name: "Behind-the-Back Wrist Curl", muscleGroups: [.forearms, .wrists], category: .arms),


        // ARM EXERCISES - TRICEPS
        Exercise(id: "tricep-pushdown", name: "Tricep Pushdown", muscleGroups: [.triceps], category: .arms),
        Exercise(id: "skull-crushers", name: "Skull Crushers", muscleGroups: [.triceps], category: .arms),
        Exercise(id: "overhead-tricep-extension", name: "Overhead Tricep Extension", muscleGroups: [.triceps], category: .arms),
        Exercise(id: "tricep-dips", name: "Tricep Dips", muscleGroups: [.triceps, .chest, .shoulders], category: .arms),
        Exercise(id: "close-grip-bench", name: "Close Grip Bench Press", muscleGroups: [.triceps, .chest], category: .arms),
        Exercise(id: "tricep-kickbacks", name: "Tricep Kickbacks", muscleGroups: [.triceps], category: .arms),
        Exercise(id: "diamond-pushups", name: "Diamond Push-Ups", muscleGroups: [.triceps, .chest], category: .arms),
        
        // ARM EXERCISES - TRICEPS (Additions)
        Exercise(id: "rope-tricep-pushdown", name: "Rope Tricep Pushdown", muscleGroups: [.triceps], category: .arms),
        Exercise(id: "v-bar-tricep-pushdown", name: "V-Bar Tricep Pushdown", muscleGroups: [.triceps], category: .arms),
        Exercise(id: "single-arm-cable-tricep-pushdown", name: "Single-Arm Cable Tricep Pushdown", muscleGroups: [.triceps], category: .arms),

        Exercise(id: "overhead-rope-tricep-extension", name: "Overhead Rope Tricep Extension", muscleGroups: [.triceps], category: .arms),
        Exercise(id: "overhead-cable-tricep-extension", name: "Overhead Cable Tricep Extension", muscleGroups: [.triceps], category: .arms),
        Exercise(id: "single-arm-overhead-cable-tricep-extension", name: "Single-Arm Overhead Cable Tricep Extension", muscleGroups: [.triceps], category: .arms),

        Exercise(id: "seated-overhead-dumbbell-tricep-extension", name: "Seated Overhead Dumbbell Tricep Extension", muscleGroups: [.triceps], category: .arms),
        Exercise(id: "single-arm-overhead-dumbbell-tricep-extension", name: "Single-Arm Overhead Dumbbell Tricep Extension", muscleGroups: [.triceps], category: .arms),

        Exercise(id: "lying-dumbbell-tricep-extension", name: "Lying Dumbbell Tricep Extension", muscleGroups: [.triceps], category: .arms),
        Exercise(id: "ez-bar-skull-crushers", name: "EZ-Bar Skull Crushers", muscleGroups: [.triceps], category: .arms),

        Exercise(id: "jm-press", name: "JM Press", muscleGroups: [.triceps, .chest], category: .arms),
        Exercise(id: "tate-press", name: "Tate Press", muscleGroups: [.triceps, .chest], category: .arms),

        Exercise(id: "bench-dips", name: "Bench Dips", muscleGroups: [.triceps, .chest, .shoulders], category: .arms),
        Exercise(id: "close-grip-pushups", name: "Close-Grip Push-Ups", muscleGroups: [.triceps, .chest, .shoulders], category: .arms),


        // ARM EXERCISES - FOREARMS
        Exercise(id: "wrist-curls", name: "Wrist Curls", muscleGroups: [.forearms, .wrists], category: .arms),
        Exercise(id: "reverse-wrist-curls", name: "Reverse Wrist Curls", muscleGroups: [.forearms, .wrists], category: .arms),
        Exercise(id: "farmers-walk", name: "Farmer's Walk", muscleGroups: [.forearms, .traps, .abs], category: .arms),
        

        // LEG EXERCISES
        Exercise(id: "squat", name: "Squat", muscleGroups: [.thighs, .glutes, .hamstrings, .lowerback], category: .legs),
        Exercise(id: "front-squat", name: "Front Squat", muscleGroups: [.thighs, .glutes, .abs], category: .legs),
        Exercise(id: "leg-press", name: "Leg Press", muscleGroups: [.thighs, .glutes, .hamstrings], category: .legs),
        Exercise(id: "lunges", name: "Lunges", muscleGroups: [.thighs, .glutes, .hamstrings], category: .legs),
        Exercise(id: "leg-extension", name: "Leg Extension", muscleGroups: [.thighs], category: .legs),
        Exercise(id: "leg-curl", name: "Leg Curl", muscleGroups: [.hamstrings], category: .legs),
        Exercise(id: "romanian-deadlift", name: "Romanian Deadlift", muscleGroups: [.hamstrings, .glutes, .lowerback], category: .legs),
        Exercise(id: "hip-thrust", name: "Hip Thrust", muscleGroups: [.glutes, .hamstrings], category: .legs),
        Exercise(id: "calf-raises", name: "Calf Raises", muscleGroups: [.calves], category: .legs),
        Exercise(id: "seated-calf-raises", name: "Seated Calf Raises", muscleGroups: [.calves], category: .legs),
        Exercise(id: "bulgarian-split-squat", name: "Bulgarian Split Squat", muscleGroups: [.thighs, .glutes, .hamstrings], category: .legs),
        Exercise(id: "goblet-squat", name: "Goblet Squat", muscleGroups: [.thighs, .glutes], category: .legs),
        Exercise(id: "hack-squat", name: "Hack Squat", muscleGroups: [.thighs, .glutes], category: .legs),
        Exercise(id: "hip-adduction", name: "Hip Adduction", muscleGroups: [.innerthigh], category: .legs),
        Exercise(id: "hip-abduction", name: "Hip Abduction", muscleGroups: [.outerthigh, .glutes], category: .legs),
        Exercise(id: "step-ups", name: "Step-Ups", muscleGroups: [.thighs, .glutes], category: .legs),
        
        // LEG EXERCISES (Additions)
        Exercise(id: "walking-lunges", name: "Walking Lunges", muscleGroups: [.thighs, .glutes, .hamstrings], category: .legs),
        Exercise(id: "reverse-lunges", name: "Reverse Lunges", muscleGroups: [.thighs, .glutes, .hamstrings], category: .legs),

        Exercise(id: "glute-bridge", name: "Glute Bridge", muscleGroups: [.glutes, .hamstrings], category: .legs),
        Exercise(id: "single-leg-romanian-deadlift", name: "Single-Leg Romanian Deadlift", muscleGroups: [.hamstrings, .glutes, .lowerback], category: .legs),

        Exercise(id: "nordic-hamstring-curl", name: "Nordic Hamstring Curl", muscleGroups: [.hamstrings, .glutes], category: .legs),
        Exercise(id: "glute-ham-raise", name: "Glute-Ham Raise", muscleGroups: [.hamstrings, .glutes], category: .legs),

        Exercise(id: "calf-press-leg-press", name: "Calf Press (Leg Press Machine)", muscleGroups: [.calves], category: .legs),
        Exercise(id: "donkey-calf-raise", name: "Donkey Calf Raise", muscleGroups: [.calves], category: .legs),


        // CORE EXERCISES
        Exercise(id: "plank", name: "Plank", muscleGroups: [.abs, .obliques, .lowerback], category: .core),
        Exercise(id: "crunches", name: "Crunches", muscleGroups: [.abs], category: .core),
        Exercise(id: "leg-raises", name: "Leg Raises", muscleGroups: [.abs, .obliques], category: .core),
        Exercise(id: "russian-twist", name: "Russian Twist", muscleGroups: [.obliques, .abs], category: .core),
        Exercise(id: "bicycle-crunches", name: "Bicycle Crunches", muscleGroups: [.abs, .obliques], category: .core),
        Exercise(id: "hanging-leg-raise", name: "Hanging Leg Raise", muscleGroups: [.abs, .obliques], category: .core),
        Exercise(id: "ab-wheel-rollout", name: "Ab Wheel Rollout", muscleGroups: [.abs, .obliques, .lowerback], category: .core),
        Exercise(id: "cable-woodchop", name: "Cable Woodchop", muscleGroups: [.obliques, .abs], category: .core),
        Exercise(id: "mountain-climbers", name: "Mountain Climbers", muscleGroups: [.abs, .obliques, .shoulders], category: .core),
        Exercise(id: "dead-bug", name: "Dead Bug", muscleGroups: [.abs, .obliques], category: .core),
        Exercise(id: "bird-dog", name: "Bird Dog", muscleGroups: [.abs, .lowerback, .glutes], category: .core),
        Exercise(id: "side-plank", name: "Side Plank", muscleGroups: [.obliques, .abs], category: .core),
        
        // CORE EXERCISES (Additions)
        Exercise(id: "cable-crunch", name: "Cable Crunch", muscleGroups: [.abs], category: .core),
        Exercise(id: "reverse-crunch", name: "Reverse Crunch", muscleGroups: [.abs], category: .core),
        Exercise(id: "hollow-hold", name: "Hollow Hold", muscleGroups: [.abs], category: .core),

        Exercise(id: "pallof-press", name: "Pallof Press", muscleGroups: [.abs, .obliques], category: .core),
        Exercise(id: "suitcase-carry", name: "Suitcase Carry", muscleGroups: [.abs, .obliques, .forearms], category: .core),

        Exercise(id: "hanging-knee-raise", name: "Hanging Knee Raise", muscleGroups: [.abs, .obliques], category: .core),


        // FULL BODY EXERCISES
        Exercise(id: "clean-and-press", name: "Clean and Press", muscleGroups: [.shoulders, .traps, .thighs, .glutes, .lowerback], category: .fullBody),
        Exercise(id: "clean", name: "Power Clean", muscleGroups: [.traps, .thighs, .glutes, .lowerback, .shoulders], category: .fullBody),
        Exercise(id: "snatch", name: "Snatch", muscleGroups: [.shoulders, .traps, .thighs, .glutes, .lowerback], category: .fullBody),
        Exercise(id: "thrusters", name: "Thrusters", muscleGroups: [.thighs, .glutes, .shoulders, .triceps], category: .fullBody),
        Exercise(id: "burpees", name: "Burpees", muscleGroups: [.chest, .thighs, .abs, .shoulders], category: .fullBody),
        Exercise(id: "kettlebell-swing", name: "Kettlebell Swing", muscleGroups: [.glutes, .hamstrings, .lowerback, .shoulders], category: .fullBody),
        Exercise(id: "turkish-getup", name: "Turkish Get-Up", muscleGroups: [.shoulders, .abs, .glutes, .thighs], category: .fullBody),
        Exercise(id: "man-makers", name: "Man Makers", muscleGroups: [.chest, .shoulders, .thighs, .abs, .triceps], category: .fullBody),

        // CARDIO
        Exercise(id: "running", name: "Running", muscleGroups: [.heart, .thighs, .calves, .hamstrings], category: .cardio),
        Exercise(id: "cycling", name: "Cycling", muscleGroups: [.heart, .thighs, .calves], category: .cardio),
        Exercise(id: "rowing", name: "Rowing", muscleGroups: [.heart, .lats, .biceps, .thighs], category: .cardio),
        Exercise(id: "jump-rope", name: "Jump Rope", muscleGroups: [.heart, .calves, .shoulders], category: .cardio),
        Exercise(id: "stair-climber", name: "Stair Climber", muscleGroups: [.heart, .thighs, .glutes, .calves], category: .cardio),
        Exercise(id: "elliptical", name: "Elliptical", muscleGroups: [.heart, .thighs, .glutes], category: .cardio),
        Exercise(id: "swimming", name: "Swimming", muscleGroups: [.heart, .lats, .shoulders, .chest], category: .cardio),

        // NECK EXERCISES
        Exercise(id: "neck-curl", name: "Neck Curl", muscleGroups: [.neck], category: .core),
        Exercise(id: "neck-extension", name: "Neck Extension", muscleGroups: [.neck, .traps], category: .core),
        Exercise(id: "neck-lateral-flexion", name: "Neck Lateral Flexion", muscleGroups: [.neck], category: .core),
    ]

    /// Get exercises that work a specific muscle group
    static func exercises(for muscleGroup: MuscleGroup) -> [Exercise] {
        exercises.filter { $0.muscleGroups.contains(muscleGroup) }
    }

    /// Get exercises grouped by category
    static func exercisesByCategory() -> [ExerciseCategory: [Exercise]] {
        Dictionary(grouping: exercises, by: { $0.category })
    }

    /// Search exercises by name
    static func search(_ query: String) -> [Exercise] {
        guard !query.isEmpty else { return exercises }
        return exercises.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }
}
