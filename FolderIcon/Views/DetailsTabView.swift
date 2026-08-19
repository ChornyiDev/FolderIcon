import SwiftUI

struct DetailsTabView: View {
    @Bindable var state: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                SectionCard(title: "Preview") {
                    IconPreviewSection(
                        isEmoji: state.selectedIconType == .emojis,
                        selectedEmoji: state.selectedEmoji,
                        selectedSymbol: state.selectedSymbol,
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
            return Color.white
        }
    }
}

struct IconPreviewSection: View {
    let isEmoji: Bool
    let selectedEmoji: String
    let selectedSymbol: String
    let previewColor: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [4]))
                .foregroundColor(.gray.opacity(0.5))
                .frame(width: 80, height: 80)

            if isEmoji && !selectedEmoji.isEmpty {
                Text(selectedEmoji).font(.system(size: 40))
            } else if !selectedSymbol.isEmpty {
                Image(systemName: selectedSymbol)
                    .font(.system(size: 40))
                    .foregroundColor(previewColor)
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
