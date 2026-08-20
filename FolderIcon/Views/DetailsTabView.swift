import SwiftUI

struct DetailsTabView: View {
    @Bindable var state: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                SectionCard(title: "Preview") {
                    IconPreviewSection(
                        iconType: state.selectedIconType,
                        selectedEmoji: state.selectedEmoji,
                        selectedSymbol: state.selectedSymbol,
                        customImage: state.customImage,
                        style: state.iconStyle,
                        previewColor: previewIconColor)
                        .frame(maxWidth: .infinity)
                }

                SectionCard(title: "Size", subtitle: "\(Int(state.symbolSize)) pt") {
                    HSBSlider(
                        value: Binding(
                            get: { Double((state.symbolSize - 80.0) / 220.0) },
                            set: { state.symbolSize = CGFloat(80.0 + ($0 * 220.0)) }
                        ),
                        gradient: Gradient(colors: [.gray, .blue]))
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

                Spacer(minLength: 0)
            }
            .padding(.vertical, 4)
        }
        .scrollIndicators(.hidden)
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

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [4]))
                .foregroundColor(.gray.opacity(0.5))
                .frame(width: 80, height: 80)

            switch iconType {
            case .emojis:
                if !selectedEmoji.isEmpty {
                    Text(selectedEmoji).font(.system(size: 40))
                }
            case .symbols:
                if !selectedSymbol.isEmpty {
                    Image(systemName: selectedSymbol)
                        .font(.system(size: 40))
                        .foregroundColor(previewColor)
                }
            case .custom:
                if let customImage {
                    Image(nsImage: customImage)
                        .resizable()
                        .renderingMode(style == .color ? .template : .original)
                        .foregroundStyle(previewColor)
                        .opacity(style == .vibrant ? 0.4 : 1)
                        .scaledToFit()
                        .frame(width: 56, height: 56)
                }
            }
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
        VStack(spacing: 12) {
            HStack(spacing: 15) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(hue: hue, saturation: sat, brightness: bri))
                    .frame(width: 40, height: 30)
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
    }
}
