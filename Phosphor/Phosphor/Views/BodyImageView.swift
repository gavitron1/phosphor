import SwiftUI
import UIKit

enum BodySide: String, CaseIterable {
    case front = "Front"
    case back = "Back"
}

struct BodyImageView: View {
    let gender: Gender
    let side: BodySide
    let highlightColor: Color
    let getIntensity: (MuscleGroup) -> Double
    let onMuscleGroupTapped: (MuscleGroup) -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Layer 1: White background (the white body)
                whiteBackgroundImage
                    .resizable()
                    .aspectRatio(contentMode: .fit)

                // Layer 2: Black background (outlines/definition on top)
                blackBackgroundImage
                    .resizable()
                    .aspectRatio(contentMode: .fit)

                // Layer 3+: Tappable muscle layers
                ForEach(muscleGroups, id: \.self) { muscleGroup in
                    MuscleLayerView(
                        muscleGroup: muscleGroup,
                        imageName: imageName(for: muscleGroup),
                        intensity: getIntensity(muscleGroup),
                        highlightColor: highlightColor,
                        onTap: { onMuscleGroupTapped(muscleGroup) }
                    )
                }

                // Top layer: Non-tappable overlay (hands, feet, knees, hair)
                nonTappableOverlay
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }

    private var blackBackgroundImage: Image {
        let prefix = gender == .male ? "male" : "female"
        let sideStr = side == .front ? "front" : "back"
        return Image("\(prefix)-\(sideStr)-body-bkg-black")
    }

    private var whiteBackgroundImage: Image {
        let prefix = gender == .male ? "male" : "female"
        let sideStr = side == .front ? "front" : "back"
        return Image("\(prefix)-\(sideStr)-body-bkg-white")
    }

    private var nonTappableOverlay: Image {
        let prefix = gender == .male ? "male" : "female"
        let sideStr = side == .front ? "front" : "back"
        if side == .front && gender == .male {
            return Image("\(prefix)-\(sideStr)-hands-feet-hair")
        } else {
            return Image("\(prefix)-\(sideStr)-body-hands-feet-knees")
        }
    }

    private var muscleGroups: [MuscleGroup] {
        side == .front ? MuscleGroup.frontMuscles : MuscleGroup.backMuscles
    }

    private func imageName(for muscleGroup: MuscleGroup) -> String? {
        side == .front ? muscleGroup.frontImageName(for: gender) : muscleGroup.backImageName(for: gender)
    }
}

struct MuscleLayerView: View {
    let muscleGroup: MuscleGroup
    let imageName: String?
    let intensity: Double
    let highlightColor: Color
    let onTap: () -> Void

    @State private var uiImage: UIImage?

    var body: some View {
        if let imageName = imageName, let uiImage = UIImage(named: imageName) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .colorMultiply(intensity > 0 ? highlightColor.opacity(0.3 + intensity * 0.7) : .white)
                .onTapGesture { location in
                    // Check if tap location has non-transparent pixel
                    if isNonTransparentPixel(at: location, in: uiImage) {
                        onTap()
                    }
                }
                .onAppear {
                    self.uiImage = uiImage
                }
        }
    }

    private func isNonTransparentPixel(at point: CGPoint, in image: UIImage) -> Bool {
        guard let cgImage = image.cgImage else { return false }

        let imageWidth = CGFloat(cgImage.width)
        let imageHeight = CGFloat(cgImage.height)

        // We need to map the tap point to image coordinates
        // This is tricky because we're using aspectRatio contentMode: .fit
        // For now, do a simple proportional mapping
        let x = Int(point.x / UIScreen.main.bounds.width * imageWidth)
        let y = Int(point.y / UIScreen.main.bounds.height * imageHeight)

        guard x >= 0, x < Int(imageWidth), y >= 0, y < Int(imageHeight) else {
            return false
        }

        guard let dataProvider = cgImage.dataProvider,
              let data = dataProvider.data,
              let bytes = CFDataGetBytePtr(data) else {
            return false
        }

        let bytesPerPixel = cgImage.bitsPerPixel / 8
        let bytesPerRow = cgImage.bytesPerRow
        let pixelOffset = y * bytesPerRow + x * bytesPerPixel

        // Check alpha channel (assuming RGBA or BGRA format)
        let alphaOffset = bytesPerPixel - 1 // Alpha is typically last
        let alpha = bytes[pixelOffset + alphaOffset]

        return alpha > 20 // Consider pixels with alpha > 20 as non-transparent
    }
}

// MARK: - Improved Hit Testing View

struct TappableBodyView: View {
    let gender: Gender
    let side: BodySide
    let highlightColor: Color
    let getIntensity: (MuscleGroup) -> Double
    let onMuscleGroupTapped: (MuscleGroup) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var viewSize: CGSize = .zero

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Layer 1: White background (the white body)
                whiteBackgroundImage
                    .resizable()
                    .aspectRatio(contentMode: .fit)

                // Layer 2: Black background (outlines/definition on top)
                blackBackgroundImage
                    .resizable()
                    .aspectRatio(contentMode: .fit)

                // Layer 3+: Muscle layers with hit testing
                ForEach(muscleGroups.reversed(), id: \.self) { muscleGroup in
                    if let imageName = imageName(for: muscleGroup) {
                        TappableMuscleLayer(
                            imageName: imageName,
                            intensity: getIntensity(muscleGroup),
                            highlightColor: highlightColor,
                            viewSize: geometry.size,
                            onTap: { onMuscleGroupTapped(muscleGroup) }
                        )
                    }
                }

                // Top layer: Non-tappable overlay
                nonTappableOverlay
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .onAppear { viewSize = geometry.size }
            .onChange(of: geometry.size) { _, newSize in viewSize = newSize }
        }
    }

    private var blackBackgroundImage: Image {
        let prefix = gender == .male ? "male" : "female"
        let sideStr = side == .front ? "front" : "back"
        return Image("\(prefix)-\(sideStr)-body-bkg-black")
    }

    private var whiteBackgroundImage: Image {
        let prefix = gender == .male ? "male" : "female"
        let sideStr = side == .front ? "front" : "back"
        return Image("\(prefix)-\(sideStr)-body-bkg-white")
    }

    private var nonTappableOverlay: Image {
        let prefix = gender == .male ? "male" : "female"
        let sideStr = side == .front ? "front" : "back"
        if side == .front && gender == .male {
            return Image("\(prefix)-\(sideStr)-hands-feet-hair")
        } else {
            return Image("\(prefix)-\(sideStr)-body-hands-feet-knees")
        }
    }

    private var muscleGroups: [MuscleGroup] {
        side == .front ? MuscleGroup.frontMuscles : MuscleGroup.backMuscles
    }

    private func imageName(for muscleGroup: MuscleGroup) -> String? {
        side == .front ? muscleGroup.frontImageName(for: gender) : muscleGroup.backImageName(for: gender)
    }
}

struct TappableMuscleLayer: View {
    let imageName: String
    let intensity: Double
    let highlightColor: Color
    let viewSize: CGSize
    let onTap: () -> Void

    var body: some View {
        if let uiImage = UIImage(named: imageName) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                // White images stay white when intensity is 0, turn to highlight color when tapped
                .colorMultiply(intensity > 0 ? highlightColor : .white)
                .opacity(intensity > 0 ? max(0.4, intensity) : 1.0)
                .contentShape(AlphaHitTestShape(image: uiImage, viewSize: viewSize))
                .onTapGesture {
                    onTap()
                }
        }
    }
}

struct AlphaHitTestShape: Shape {
    let image: UIImage
    let viewSize: CGSize

    func path(in rect: CGRect) -> Path {
        // Return full rect - actual hit testing done in contains
        Path(rect)
    }
}

extension AlphaHitTestShape: InsettableShape {
    func inset(by amount: CGFloat) -> some InsettableShape {
        self
    }
}

// MARK: - UIKit-based Alpha Hit Testing

struct AlphaHitTestView: UIViewRepresentable {
    let imageName: String
    let intensity: Double
    let highlightColor: Color
    let onTap: () -> Void

    func makeUIView(context: Context) -> AlphaHitTestUIView {
        let view = AlphaHitTestUIView()
        view.imageName = imageName
        view.onTap = onTap
        view.updateAppearance(intensity: intensity, highlightColor: UIColor(highlightColor))
        return view
    }

    func updateUIView(_ uiView: AlphaHitTestUIView, context: Context) {
        uiView.updateAppearance(intensity: intensity, highlightColor: UIColor(highlightColor))
    }
}

class AlphaHitTestUIView: UIView {
    var imageName: String = "" {
        didSet {
            originalImage = UIImage(named: imageName)
            imageView.image = originalImage
        }
    }
    var onTap: (() -> Void)?
    private var originalImage: UIImage?
    private let imageView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(imageView)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        addGestureRecognizer(tap)
    }

    func updateAppearance(intensity: Double, highlightColor: UIColor) {
        guard let original = originalImage else { return }

        if intensity > 0 {
            imageView.image = original.tinted(with: highlightColor.withAlphaComponent(CGFloat(0.3 + intensity * 0.7)))
        } else {
            imageView.image = original
        }
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: imageView)

        guard let image = originalImage,
              isNonTransparent(at: location, in: image, imageViewSize: imageView.bounds.size) else {
            return
        }

        onTap?()
    }

    private func isNonTransparent(at point: CGPoint, in image: UIImage, imageViewSize: CGSize) -> Bool {
        guard let cgImage = image.cgImage else { return false }

        let imageSize = image.size
        let scale = min(imageViewSize.width / imageSize.width, imageViewSize.height / imageSize.height)
        let scaledImageSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)

        let offsetX = (imageViewSize.width - scaledImageSize.width) / 2
        let offsetY = (imageViewSize.height - scaledImageSize.height) / 2

        let adjustedX = point.x - offsetX
        let adjustedY = point.y - offsetY

        guard adjustedX >= 0, adjustedX < scaledImageSize.width,
              adjustedY >= 0, adjustedY < scaledImageSize.height else {
            return false
        }

        let imageX = Int(adjustedX / scale * image.scale)
        let imageY = Int(adjustedY / scale * image.scale)

        guard imageX >= 0, imageX < cgImage.width,
              imageY >= 0, imageY < cgImage.height else {
            return false
        }

        guard let dataProvider = cgImage.dataProvider,
              let data = dataProvider.data,
              let bytes = CFDataGetBytePtr(data) else {
            return false
        }

        let bytesPerPixel = cgImage.bitsPerPixel / 8
        let bytesPerRow = cgImage.bytesPerRow
        let pixelOffset = imageY * bytesPerRow + imageX * bytesPerPixel

        // Alpha is typically the last component
        let alpha = bytes[pixelOffset + bytesPerPixel - 1]

        return alpha > 20
    }
}

extension UIImage {
    func tinted(with color: UIColor) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        defer { UIGraphicsEndImageContext() }

        guard let context = UIGraphicsGetCurrentContext(),
              let cgImage = cgImage else {
            return self
        }

        let rect = CGRect(origin: .zero, size: size)

        context.translateBy(x: 0, y: size.height)
        context.scaleBy(x: 1.0, y: -1.0)

        context.setBlendMode(.normal)
        context.draw(cgImage, in: rect)

        context.setBlendMode(.sourceAtop)
        color.setFill()
        context.fill(rect)

        return UIGraphicsGetImageFromCurrentImageContext() ?? self
    }
}

#Preview {
    TappableBodyView(
        gender: .male,
        side: .front,
        highlightColor: .orange,
        getIntensity: { _ in 0.5 },
        onMuscleGroupTapped: { _ in }
    )
}
