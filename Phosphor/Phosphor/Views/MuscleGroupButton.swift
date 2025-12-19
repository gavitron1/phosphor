import SwiftUI

struct MuscleGroupButton: View {
    let muscleGroup: MuscleGroup
    let intensity: Double
    let highlightColor: Color
    let onTap: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: {
            withAnimation(.easeOut(duration: 0.1)) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeIn(duration: 0.1)) {
                    isPressed = false
                }
            }
            onTap()
        }) {
            VStack(spacing: 8) {
                Image(systemName: muscleGroup.systemImage)
                    .font(.system(size: 28))
                    .foregroundColor(intensity > 0.5 ? .white : .primary)

                Text(muscleGroup.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(intensity > 0.5 ? .white : .primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(backgroundColor)
                    .shadow(color: shadowColor, radius: intensity > 0 ? 8 : 2, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(borderColor, lineWidth: 2)
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var backgroundColor: Color {
        if intensity > 0 {
            return highlightColor.opacity(intensity)
        }
        return Color(.systemGray6)
    }

    private var borderColor: Color {
        if intensity > 0 {
            return highlightColor.opacity(min(1, intensity + 0.3))
        }
        return Color(.systemGray4)
    }

    private var shadowColor: Color {
        if intensity > 0 {
            return highlightColor.opacity(intensity * 0.5)
        }
        return Color.black.opacity(0.1)
    }
}

#Preview {
    VStack {
        HStack {
            MuscleGroupButton(
                muscleGroup: .chest,
                intensity: 0.8,
                highlightColor: .orange,
                onTap: {}
            )
            .frame(width: 100, height: 100)

            MuscleGroupButton(
                muscleGroup: .abs,
                intensity: 0.3,
                highlightColor: .orange,
                onTap: {}
            )
            .frame(width: 100, height: 100)
        }

        HStack {
            MuscleGroupButton(
                muscleGroup: .biceps,
                intensity: 0,
                highlightColor: .orange,
                onTap: {}
            )
            .frame(width: 100, height: 100)

            MuscleGroupButton(
                muscleGroup: .quadriceps,
                intensity: 1.0,
                highlightColor: .orange,
                onTap: {}
            )
            .frame(width: 100, height: 100)
        }
    }
    .padding()
}
