import SwiftUI

struct BodyView: View {
    @ObservedObject var dataManager = DataManager.shared

    @State private var showStats = false
    @State private var showSettings = false
    @State private var showWeightInput = false
    @State private var currentSide: BodySide = .front

    var body: some View {
        ZStack {
            // Background
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Body image view
                TappableBodyView(
                    gender: dataManager.settings.gender,
                    side: currentSide,
                    highlightColor: dataManager.settings.highlightColor.color,
                    getIntensity: { dataManager.getIntensity(for: $0) },
                    onMuscleGroupTapped: { muscleGroup in
                        dataManager.tapMuscleGroup(muscleGroup)
                        hapticFeedback()
                    }
                )
                .padding(.horizontal)
                .padding(.top, 60)
                .padding(.bottom, 20)

                // Weight button and Front/Back toggle
                HStack {
                    Spacer()

                    // Front/Back toggle
                    Picker("Side", selection: $currentSide) {
                        ForEach(BodySide.allCases, id: \.self) { side in
                            Text(side.rawValue).tag(side)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 160)

                    Spacer()

                    // Weight button (bottom right)
                    WeightButton(
                        latestWeight: dataManager.latestWeight,
                        weightUnit: dataManager.settings.weightUnit,
                        highlightColor: dataManager.settings.highlightColor.color,
                        action: { showWeightInput = true }
                    )
                    .padding(.trailing, 16)
                }
                .padding(.bottom, 20)
            }

            // Top navigation buttons
            VStack {
                HStack {
                    // Stats button (top left)
                    GlassCircleButton(
                        systemName: "chart.bar.fill",
                        color: dataManager.settings.highlightColor.color,
                        action: { showStats = true }
                    )

                    Spacer()

                    // Settings button (top right)
                    GlassCircleButton(
                        systemName: "gearshape.fill",
                        color: dataManager.settings.highlightColor.color,
                        action: { showSettings = true }
                    )
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                Spacer()
            }
        }
        .fullScreenCover(isPresented: $showStats) {
            StatsView()
        }
        .fullScreenCover(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showWeightInput) {
            WeightInputView(
                weightUnit: dataManager.settings.weightUnit,
                highlightColor: dataManager.settings.highlightColor.color,
                onSave: { weight in
                    dataManager.addWeight(weight)
                }
            )
            .presentationDetents([.height(200)])
        }
    }

    private func hapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
}

// MARK: - Glass Circle Button

struct GlassCircleButton: View {
    let systemName: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 44, height: 44)
        }
        .modifier(GlassEffectModifier())
    }
}

struct GlassEffectModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .background(.regularMaterial, in: Circle())
                .glassEffect(.regular.interactive())
        } else {
            content
                .background(
                    Circle()
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
                )
        }
    }
}

// MARK: - Weight Button

struct WeightButton: View {
    let latestWeight: WeightEntry?
    let weightUnit: WeightUnit
    let highlightColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "scalemass.fill")
                    .font(.system(size: 12))
                if let weight = latestWeight {
                    Text(String(format: "%.1f", weight.weight))
                        .font(.system(size: 14, weight: .semibold))
                    Text(weightUnit.rawValue)
                        .font(.system(size: 11))
                } else {
                    Text("Add Weight")
                        .font(.system(size: 12, weight: .medium))
                }
            }
            .foregroundStyle(highlightColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .modifier(GlassEffectModifier())
    }
}

// MARK: - Weight Input View

struct WeightInputView: View {
    let weightUnit: WeightUnit
    let highlightColor: Color
    let onSave: (Double) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var weightText: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 20) {
            Text("Enter Weight")
                .font(.headline)
                .padding(.top, 20)

            HStack(spacing: 8) {
                TextField("0.0", text: $weightText)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .frame(width: 120)
                    .focused($isFocused)

                Text(weightUnit.rawValue)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.secondary)
            }

            Button(action: saveWeight) {
                Text("Save")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(highlightColor)
                    .cornerRadius(12)
            }
            .disabled(Double(weightText) == nil)
            .padding(.horizontal, 40)

            Spacer()
        }
        .onAppear {
            isFocused = true
        }
    }

    private func saveWeight() {
        if let weight = Double(weightText), weight > 0 {
            onSave(weight)
            dismiss()
        }
    }
}

#Preview {
    BodyView()
}
