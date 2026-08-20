import SwiftUI

struct DetailsTabView: View {
    @Bindable var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionCard(title: "Icon", subtitle: "\(Int(state.symbolSize)) pt") {
                HStack(spacing: 16) {
                    IconPreviewSection(
                        iconType: state.selectedIconType,
                        selectedEmoji: state.selectedEmoji,
                        selectedSymbol: state.selectedSymbol,
                        customImage: state.customImage,
                        style: state.iconStyle,
                        previewColor: previewIconColor,
                        offsetX: state.iconOffsetX,
                        offsetY: state.iconOffsetY)
                        .frame(width: 80)

                    Divider()
                        .frame(height: 72)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Size")
                            .font(.system(size: 12, weight: .semibold))

                        HSBSlider(
                            value: Binding(
                                get: { Double((state.symbolSize - 80.0) / 220.0) },
                                set: { state.symbolSize = CGFloat(80.0 + ($0 * 220.0)) }
                            ),
                            gradient: Gradient(colors: [.gray, .blue]))
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            SectionCard(title: "Style") {
                StylePickerSection(style: $state.iconStyle)
            }

            if state.iconStyle == .color {
                SectionCard(title: "Icon Color", subtitle: state.iconColor.hex) {
                    IconColorSection(
                        hue: $state.iconColor.hue,
                        sat: $state.iconColor.saturation,
                        bri: $state.iconColor.brightness)
                }
            }

            SectionCard(
                title: "Position",
                subtitle: "\(Int(state.iconOffsetX)), \(Int(state.iconOffsetY))") {
                IconPositionSection(
                    offsetX: $state.iconOffsetX,
                    offsetY: $state.iconOffsetY)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var previewIconColor: Color {
        switch state.iconStyle {
        case .vibrant:
            return Color.black.opacity(0.4)
        case .original:
            return Color.black
        case .color:
            return state.iconColor.color
        case .inverted:
            let referenceColor: NSColor
            switch state.tintMode {
            case .solid:
                referenceColor = state.folderColor.nsColor
            case .gradient:
                referenceColor = FolderTint.gradient(
                    start: state.gradientStart.nsColor,
                    end: state.gradientEnd.nsColor,
                    angle: state.gradientAngle
                ).referenceColor
            }
            guard let rgb = referenceColor.usingColorSpace(.sRGB) else { return .white }
            return Color(
                red: 1 - rgb.redComponent,
                green: 1 - rgb.greenComponent,
                blue: 1 - rgb.blueComponent)
        }
    }
}

struct IconPreviewSection: View {
    let iconType: IconType
    let selectedEmoji: String
    let selectedSymbol: String
    let customImage: NSImage?
    let style: IconStyle
    let previewColor: Color
    let offsetX: CGFloat
    let offsetY: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [4]))
                .foregroundColor(.gray.opacity(0.5))
                .frame(width: 80, height: 80)

            switch iconType {
            case .emojis:
                if !selectedEmoji.isEmpty {
                    Text(selectedEmoji)
                        .font(.system(size: 40))
                        .foregroundStyle(selectedEmoji.containsEmoji ? Color.primary : previewColor)
                        .offset(previewOffset)
                }
            case .symbols:
                if !selectedSymbol.isEmpty {
                    Image(systemName: selectedSymbol)
                        .font(.system(size: 40))
                        .foregroundColor(previewColor)
                        .offset(previewOffset)
                }
            case .custom:
                if let customImage {
                    Image(nsImage: customImage)
                        .resizable()
                        .renderingMode(style == .color || style == .inverted ? .template : .original)
                        .foregroundStyle(previewColor)
                        .opacity(style == .vibrant ? 0.4 : 1)
                        .scaledToFit()
                        .frame(width: 56, height: 56)
                        .offset(previewOffset)
                }
            }
        }
    }

    private var previewOffset: CGSize {
        CGSize(width: offsetX * 80 / FolderProcessor.canvasSize, height: -offsetY * 80 / FolderProcessor.canvasSize)
    }
}

private extension String {
    var containsEmoji: Bool {
        unicodeScalars.contains {
            $0.properties.isEmojiPresentation
                || ($0.properties.isEmoji && $0.value > 0x238C)
        }
    }
}

struct StylePickerSection: View {
    @Binding var style: IconStyle

    var body: some View {
        HStack(spacing: 0) {
            ForEach(IconStyle.allCases, id: \.self) { s in
                Button(action: { style = s }) {
                    Text(s.rawValue)
                        .font(.system(size: 11))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(style == s ? Color.white : Color.clear)
                        .cornerRadius(6)
                        .shadow(radius: style == s ? 1 : 0)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(2)
            }
        }
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

struct IconColorSection: View {
    @Binding var hue: Double
    @Binding var sat: Double
    @Binding var bri: Double

    var body: some View {
        VStack(spacing: 15) {
            HSBSlider(
                value: $hue,
                gradient: Gradient(
                    colors: (0...10).map {
                        Color(hue: Double($0) / 10.0, saturation: 1, brightness: 1)
                    }))
            HSBSlider(
                value: $sat,
                gradient: Gradient(colors: [
                    .white, Color(hue: hue, saturation: 1, brightness: bri),
                ]))
        }
    }
}

struct IconPositionSection: View {
    @Binding var offsetX: CGFloat
    @Binding var offsetY: CGFloat

    private let maximumOffset: CGFloat = 110

    var body: some View {
        VStack(spacing: 10) {
            Text("Drag the circle to move the icon on the folder")
                .font(.system(size: 10))
                .foregroundColor(.secondary)

            GeometryReader { proxy in
                let diameter = min(proxy.size.width, proxy.size.height)
                let center = CGPoint(x: diameter / 2, y: diameter / 2)
                let radius = max(1, diameter / 2 - 14)

                ZStack {
                    Circle()
                        .fill(Color.gray.opacity(0.06))
                        .overlay(Circle().stroke(Color.gray.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4])))

                    Path { path in
                        path.move(to: CGPoint(x: 0, y: center.y))
                        path.addLine(to: CGPoint(x: diameter, y: center.y))
                        path.move(to: CGPoint(x: center.x, y: 0))
                        path.addLine(to: CGPoint(x: center.x, y: diameter))
                    }
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)

                    Circle()
                        .fill(Color.blue)
                        .frame(width: 22, height: 22)
                        .overlay(Circle().stroke(Color.white, lineWidth: 3))
                        .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
                        .position(handlePosition(center: center, radius: radius))
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    updatePosition(value.location, center: center, radius: radius)
                                })
                }
                .frame(width: diameter, height: diameter)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(height: 150)

            Button("Reset position") {
                offsetX = 0
                offsetY = 0
            }
            .buttonStyle(.plain)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.blue)
            .disabled(offsetX == 0 && offsetY == 0)
        }
    }

    private func handlePosition(center: CGPoint, radius: CGFloat) -> CGPoint {
        CGPoint(
            x: center.x + offsetX / maximumOffset * radius,
            y: center.y - offsetY / maximumOffset * radius)
    }

    private func updatePosition(_ location: CGPoint, center: CGPoint, radius: CGFloat) {
        offsetX = max(-maximumOffset, min(maximumOffset, (location.x - center.x) / radius * maximumOffset))
        offsetY = max(-maximumOffset, min(maximumOffset, (center.y - location.y) / radius * maximumOffset))
    }
}
