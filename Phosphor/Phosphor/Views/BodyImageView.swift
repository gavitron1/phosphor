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
                // Layer 1: Black background (bottom)
                blackBackgroundImage
                    .resizable()
                    .aspectRatio(contentMode: .fit)

                // Layer 2: White background (above black) - invert colors since PNG is black
                whiteBackgroundImage
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .colorInvert()

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
    let darkMode: Bool
    let cooldownDays: Double  // Added to trigger re-render when cooldown changes
    let getIntensity: (MuscleGroup) -> Double
    let onMuscleGroupTapped: (MuscleGroup) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var viewSize: CGSize = .zero

    // Cache loaded images for hit testing
    @State private var muscleImages: [MuscleGroup: UIImage] = [:]

    // The base color muscles fade to (white in light mode, black in dark mode)
    private var baseColor: Color {
        darkMode ? .black : .white
    }

    // Blend highlight color with base color based on intensity
    private func muscleColor(for intensity: Double) -> Color {
        if intensity <= 0 {
            return baseColor
        }
        // Interpolate between base color and highlight color
        // intensity of 1.0 = full highlight, intensity of 0.0 = base color
        return Color(
            UIColor(highlightColor).interpolate(to: UIColor(baseColor), fraction: 1.0 - intensity)
        )
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if darkMode {
                    // Dark mode: White background with black body outline
                    whiteBackgroundImage
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .colorInvert()

                    blackBackgroundImage
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .colorInvert()
                } else {
                    // Light mode: Black background (bottom)
                    blackBackgroundImage
                        .resizable()
                        .aspectRatio(contentMode: .fit)

                    // White background (above black) - invert colors since PNG is black
                    whiteBackgroundImage
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .colorInvert()
                }

                // Muscle layers (display only, no individual hit testing)
                ForEach(muscleGroups, id: \.self) { muscleGroup in
                    if let imageName = imageName(for: muscleGroup),
                       let uiImage = UIImage(named: imageName) {
                        let intensity = getIntensity(muscleGroup)
                        Image(uiImage: uiImage.withRenderingMode(.alwaysTemplate))
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .foregroundColor(muscleColor(for: intensity))
                    }
                }

                // Top layer: Non-tappable overlay
                if darkMode {
                    nonTappableOverlay
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .colorInvert()
                } else {
                    nonTappableOverlay
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .contentShape(Rectangle())
            .gesture(
                SpatialTapGesture()
                    .onEnded { value in
                        handleTap(at: value.location, viewSize: geometry.size)
                    }
            )
            .onAppear {
                viewSize = geometry.size
                loadMuscleImages()
            }
            .onChange(of: geometry.size) { _, newSize in viewSize = newSize }
            .onChange(of: side) { _, _ in loadMuscleImages() }
        }
    }

    private func loadMuscleImages() {
        for muscleGroup in muscleGroups {
            if let imageName = imageName(for: muscleGroup),
               let image = UIImage(named: imageName) {
                muscleImages[muscleGroup] = image
            }
        }
    }

    private func handleTap(at point: CGPoint, viewSize: CGSize) {
        // Check muscle groups from top to bottom (reversed order)
        for muscleGroup in muscleGroups.reversed() {
            if let image = muscleImages[muscleGroup],
               isNonTransparentPixel(at: point, in: image, viewSize: viewSize) {
                print("HIT: \(muscleGroup.rawValue)")
                onMuscleGroupTapped(muscleGroup)
                return // Stop at first hit
            }
        }
        print("No muscle hit at \(point)")
    }

    private func isNonTransparentPixel(at point: CGPoint, in image: UIImage, viewSize: CGSize) -> Bool {
        guard let cgImage = image.cgImage else { return false }

        let imageWidth = CGFloat(cgImage.width)
        let imageHeight = CGFloat(cgImage.height)

        // Calculate the actual displayed image size (aspect fit)
        let imageAspect = imageWidth / imageHeight
        let viewAspect = viewSize.width / viewSize.height

        var displayedWidth: CGFloat
        var displayedHeight: CGFloat
        var offsetX: CGFloat = 0
        var offsetY: CGFloat = 0

        if imageAspect > viewAspect {
            displayedWidth = viewSize.width
            displayedHeight = viewSize.width / imageAspect
            offsetY = (viewSize.height - displayedHeight) / 2
        } else {
            displayedHeight = viewSize.height
            displayedWidth = viewSize.height * imageAspect
            offsetX = (viewSize.width - displayedWidth) / 2
        }

        let adjustedX = point.x - offsetX
        let adjustedY = point.y - offsetY

        guard adjustedX >= 0, adjustedX < displayedWidth,
              adjustedY >= 0, adjustedY < displayedHeight else {
            return false
        }

        let imageX = Int(adjustedX / displayedWidth * imageWidth)
        let imageY = Int(adjustedY / displayedHeight * imageHeight)

        guard imageX >= 0, imageX < Int(imageWidth),
              imageY >= 0, imageY < Int(imageHeight) else {
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

        let alpha = bytes[pixelOffset + bytesPerPixel - 1]
        return alpha > 30
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

    @State private var imageSize: CGSize = .zero

    // Blend from white to highlight color based on intensity
    private var currentColor: Color {
        if intensity <= 0 {
            return .white
        } else {
            return highlightColor
        }
    }

    var body: some View {
        if let uiImage = UIImage(named: imageName) {
            GeometryReader { geometry in
                Image(uiImage: uiImage.withRenderingMode(.alwaysTemplate))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundColor(currentColor)
                    .opacity(intensity > 0 ? max(0.5, intensity) : 1.0)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .contentShape(Rectangle())
                    .gesture(
                        SpatialTapGesture()
                            .onEnded { value in
                                let location = value.location
                                if isNonTransparentPixel(at: location, in: uiImage, viewSize: geometry.size) {
                                    print("Tapped \(imageName) at \(location) - HIT!")
                                    onTap()
                                } else {
                                    print("Tapped \(imageName) at \(location) - transparent, passing through")
                                }
                            }
                    )
                    .onAppear {
                        imageSize = geometry.size
                    }
            }
        }
    }

    private func isNonTransparentPixel(at point: CGPoint, in image: UIImage, viewSize: CGSize) -> Bool {
        guard let cgImage = image.cgImage else { return false }

        let imageWidth = CGFloat(cgImage.width)
        let imageHeight = CGFloat(cgImage.height)

        // Calculate the actual displayed image size (aspect fit)
        let imageAspect = imageWidth / imageHeight
        let viewAspect = viewSize.width / viewSize.height

        var displayedWidth: CGFloat
        var displayedHeight: CGFloat
        var offsetX: CGFloat = 0
        var offsetY: CGFloat = 0

        if imageAspect > viewAspect {
            // Image is wider - fit to width
            displayedWidth = viewSize.width
            displayedHeight = viewSize.width / imageAspect
            offsetY = (viewSize.height - displayedHeight) / 2
        } else {
            // Image is taller - fit to height
            displayedHeight = viewSize.height
            displayedWidth = viewSize.height * imageAspect
            offsetX = (viewSize.width - displayedWidth) / 2
        }

        // Adjust tap point for offset
        let adjustedX = point.x - offsetX
        let adjustedY = point.y - offsetY

        // Check if tap is within the displayed image bounds
        guard adjustedX >= 0, adjustedX < displayedWidth,
              adjustedY >= 0, adjustedY < displayedHeight else {
            return false
        }

        // Convert to image coordinates
        let imageX = Int(adjustedX / displayedWidth * imageWidth)
        let imageY = Int(adjustedY / displayedHeight * imageHeight)

        guard imageX >= 0, imageX < Int(imageWidth),
              imageY >= 0, imageY < Int(imageHeight) else {
            return false
        }

        // Get pixel data
        guard let dataProvider = cgImage.dataProvider,
              let data = dataProvider.data,
              let bytes = CFDataGetBytePtr(data) else {
            return false
        }

        let bytesPerPixel = cgImage.bitsPerPixel / 8
        let bytesPerRow = cgImage.bytesPerRow
        let pixelOffset = imageY * bytesPerRow + imageX * bytesPerPixel

        // Check alpha channel (last byte in RGBA)
        let alpha = bytes[pixelOffset + bytesPerPixel - 1]

        return alpha > 30 // Consider non-transparent if alpha > 30
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

extension UIColor {
    func interpolate(to color: UIColor, fraction: Double) -> UIColor {
        let f = CGFloat(max(0, min(1, fraction)))

        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0

        self.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        color.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)

        return UIColor(
            red: r1 + (r2 - r1) * f,
            green: g1 + (g2 - g1) * f,
            blue: b1 + (b2 - b1) * f,
            alpha: a1 + (a2 - a1) * f
        )
    }
}

#Preview {
    TappableBodyView(
        gender: .male,
        side: .front,
        highlightColor: .orange,
        darkMode: false,
        cooldownDays: 3,
        getIntensity: { _ in 0.5 },
        onMuscleGroupTapped: { _ in }
    )
}
