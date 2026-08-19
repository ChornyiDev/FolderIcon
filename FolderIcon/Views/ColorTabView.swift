import AppKit
import SwiftUI

struct ColorTabView: View {
    @Bindable var state: AppState

    private struct GradientPreset {
        let name: String
        let start: HSBColor
        let end: HSBColor
        let angle: Double
    }

    private let gradientPresets: [GradientPreset] = [
        GradientPreset(
            name: "Sunrise",
            start: HSBColor(hue: 0.02, saturation: 0.9, brightness: 0.95),
            end: HSBColor(hue: 0.13, saturation: 0.9, brightness: 1.0), angle: 90),
        GradientPreset(
            name: "Sunset",
            start: HSBColor(hue: 0.95, saturation: 0.8, brightness: 0.9),
            end: HSBColor(hue: 0.06, saturation: 0.9, brightness: 0.95), angle: 90),
        GradientPreset(
            name: "Ocean",
            start: HSBColor(hue: 0.52, saturation: 0.85, brightness: 0.8),
            end: HSBColor(hue: 0.65, saturation: 0.9, brightness: 0.6), angle: 45),
        GradientPreset(
            name: "Forest",
            start: HSBColor(hue: 0.3, saturation: 0.8, brightness: 0.6),
            end: HSBColor(hue: 0.45, saturation: 0.8, brightness: 0.7), angle: 90),
        GradientPreset(
            name: "Purple Haze",
            start: HSBColor(hue: 0.75, saturation: 0.8, brightness: 0.85),
            end: HSBColor(hue: 0.62, saturation: 0.85, brightness: 0.9), angle: 135),
        GradientPreset(
            name: "Candy",
            start: HSBColor(hue: 0.9, saturation: 0.85, brightness: 0.95),
            end: HSBColor(hue: 0.75, saturation: 0.8, brightness: 0.9), angle: 45),
        GradientPreset(
            name: "Midnight",
            start: HSBColor(hue: 0.66, saturation: 0.9, brightness: 0.45),
            end: HSBColor(hue: 0.72, saturation: 0.6, brightness: 0.2), angle: 90),
        GradientPreset(
            name: "Gold",
            start: HSBColor(hue: 0.11, saturation: 0.9, brightness: 1.0),
            end: HSBColor(hue: 0.07, saturation: 0.95, brightness: 0.85), angle: 90),
        GradientPreset(
            name: "Cherry",
            start: HSBColor(hue: 0.98, saturation: 0.85, brightness: 0.85),
            end: HSBColor(hue: 0.88, saturation: 0.8, brightness: 0.95), angle: 45),
        GradientPreset(
            name: "Lagoon",
            start: HSBColor(hue: 0.5, saturation: 0.85, brightness: 0.85),
            end: HSBColor(hue: 0.35, saturation: 0.8, brightness: 0.7), angle: 45),
        GradientPreset(
            name: "Peach",
            start: HSBColor(hue: 0.06, saturation: 0.7, brightness: 1.0),
            end: HSBColor(hue: 0.95, saturation: 0.6, brightness: 1.0), angle: 90),
        GradientPreset(
            name: "Steel",
            start: HSBColor(hue: 0.6, saturation: 0.35, brightness: 0.75),
            end: HSBColor(hue: 0.62, saturation: 0.6, brightness: 0.4), angle: 90),
        GradientPreset(
            name: "Tropic",
            start: HSBColor(hue: 0.45, saturation: 0.85, brightness: 0.95),
            end: HSBColor(hue: 0.55, saturation: 0.9, brightness: 0.6), angle: 135),
        GradientPreset(
            name: "Magma",
            start: HSBColor(hue: 0.03, saturation: 0.9, brightness: 0.9),
            end: HSBColor(hue: 0.08, saturation: 1.0, brightness: 0.45), angle: 90),
        GradientPreset(
            name: "Berry",
            start: HSBColor(hue: 0.8, saturation: 0.9, brightness: 0.8),
            end: HSBColor(hue: 0.93, saturation: 0.8, brightness: 0.4), angle: 45),
        GradientPreset(
            name: "Silver",
            start: HSBColor(hue: 0.6, saturation: 0.1, brightness: 0.95),
            end: HSBColor(hue: 0.63, saturation: 0.2, brightness: 0.6), angle: 90),
    ]

    private let solidPresets: [Color] = [
        .red,
        Color(red: 1.0, green: 0.55, blue: 0.55),  // coral
        .orange,
        Color(red: 1.0, green: 0.8, blue: 0.6),    // peach
        .yellow,
        Color(red: 0.65, green: 0.9, blue: 0.45),  // lime
        .green,
        .mint,
        .teal,
        .cyan,
        Color(red: 0.55, green: 0.8, blue: 1.0),   // sky
        .blue,
        .indigo,
        .purple,
        Color(red: 0.85, green: 0.65, blue: 1.0),  // lavender
        .pink,
        .brown,
        Color(red: 0.6, green: 0.6, blue: 0.2),    // olive
        .gray,
        .white,
        Color(red: 0.75, green: 0.75, blue: 0.78), // silver
        Color(red: 0.5, green: 0.2, blue: 0.25),   // maroon
        .black,
        Color(red: 0.1, green: 0.15, blue: 0.35),  // navy
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                modePicker

                if state.tintMode == .gradient {
                    SectionCard(title: "Colors") {
                        gradientControlRow
                    }

                    SectionCard(title: slotSliderTitle, subtitle: slotHex) {
                        hsbSliders(for: activeColorBinding)
                    }
                } else {
                    SectionCard(title: "Color", subtitle: state.folderColorHex) {
                        hsbSliders(for: $state.folderColor)
                    }
                }

                SectionCard(title: "Opacity", subtitle: "\(Int(state.tintOpacity * 100))%") {
                    Slider(value: $state.tintOpacity, in: 0...1)
                        .controlSize(.small)
                }

                SectionCard(title: "Presets") {
                    if state.tintMode == .gradient {
                        gradientPresetsGrid
                    } else {
                        solidPresetsGrid
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.vertical, 4)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Mode Picker

    private var modePicker: some View {
        HStack(spacing: 0) {
            ForEach(TintMode.allCases, id: \.self) { mode in
                let isActive = state.tintMode == mode
                Button(action: { state.tintMode = mode }) {
                    Text(mode.rawValue)
                        .font(.system(size: 12, weight: isActive ? .bold : .regular))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(isActive ? Color.white : Color.clear)
                        .cornerRadius(6)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(2)
            }
        }
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }

    // MARK: - Gradient Control Row

    /// Single row: [Start][gradient preview][End] + 8 direction arrows.
    /// Slot buttons share the arrow button style, but wider.
    private var gradientControlRow: some View {
        HStack(spacing: 8) {
            slotButton(.start)
            gradientBar
            slotButton(.end)

            Divider()
                .frame(height: 24)

            GradientDirectionPicker(angle: $state.gradientAngle)
        }
    }

    private var slotSliderTitle: String {
        state.activeGradientSlot == .start ? "Start Color" : "End Color"
    }

    private var slotHex: String {
        (state.activeGradientSlot == .start ? state.gradientStart : state.gradientEnd).hex
    }

    private func slotButton(_ slot: GradientSlot) -> some View {
        let isActive = state.activeGradientSlot == slot
        let hsb = slot == .start ? state.gradientStart : state.gradientEnd
        let label = slot == .start ? "Start" : "End"

        return Button(action: { state.activeGradientSlot = slot }) {
            RoundedRectangle(cornerRadius: 8)
                .fill(hsb.color)
                .frame(width: 44, height: 30)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            isActive ? Color.blue : Color.gray.opacity(0.4),
                            lineWidth: isActive ? 2 : 1))
                .shadow(color: isActive ? .blue.opacity(0.4) : .clear, radius: 3)
        }
        .buttonStyle(.plain)
        .help("\(label) color — #\(hsb.hex). Click to edit with the sliders below.")
    }

    /// Live gradient preview, oriented along the chosen direction.
    private var gradientBar: some View {
        let points = gradientBarPoints
        return RoundedRectangle(cornerRadius: 8)
            .fill(
                LinearGradient(
                    colors: [state.gradientStart.color, state.gradientEnd.color],
                    startPoint: points.0,
                    endPoint: points.1))
            .frame(height: 30)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.25)))
    }

    /// Angle (0° = left-to-right, 90° = bottom-to-top) mapped to
    /// bar-relative UnitPoints.
    private var gradientBarPoints: (UnitPoint, UnitPoint) {
        let radians = state.gradientAngle * .pi / 180
        let dx = cos(radians)
        let dy = -sin(radians)
        return (
            UnitPoint(x: 0.5 - dx * 0.5, y: 0.5 - dy * 0.5),
            UnitPoint(x: 0.5 + dx * 0.5, y: 0.5 + dy * 0.5)
        )
    }

    // MARK: - Color Sliders (shared)

    private var activeColorBinding: Binding<HSBColor> {
        switch state.tintMode {
        case .solid:
            return $state.folderColor
        case .gradient:
            return state.activeGradientSlot == .start ? $state.gradientStart : $state.gradientEnd
        }
    }

    private func hsbSliders(for color: Binding<HSBColor>) -> some View {
        VStack(spacing: 12) {
            sliderRow(
                title: "Hue", value: color.hue,
                formatted: { "\(Int($0 * 360))°" },
                gradient: Gradient(
                    colors: (0...10).map {
                        Color(hue: Double($0) / 10.0, saturation: 1, brightness: 1)
                    }))

            sliderRow(
                title: "Saturation", value: color.saturation,
                formatted: { "\(Int($0 * 100))%" },
                gradient: Gradient(colors: [
                    Color(
                        hue: color.wrappedValue.hue, saturation: 0,
                        brightness: color.wrappedValue.brightness),
                    Color(
                        hue: color.wrappedValue.hue, saturation: 1,
                        brightness: color.wrappedValue.brightness),
                ]))

            sliderRow(
                title: "Brightness", value: color.brightness,
                formatted: { "\(Int($0 * 100))%" },
                gradient: Gradient(colors: [
                    .black,
                    Color(
                        hue: color.wrappedValue.hue,
                        saturation: color.wrappedValue.saturation, brightness: 1),
                ]))
        }
    }

    private func sliderRow(
        title: String,
        value: Binding<Double>,
        formatted: @escaping (Double) -> String,
        gradient: Gradient
    ) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
                Spacer()
                Text(formatted(value.wrappedValue))
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            HSBSlider(value: value, gradient: gradient)
        }
    }

    // MARK: - Presets

    private var solidPresetsGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 10) {
            ForEach(solidPresets, id: \.self) { color in
                Button(action: {
                    state.folderColor = HSBColor(color: color)
                }) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(color)
                        .frame(height: 34)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.2)))
                }
                .buttonStyle(.plain)
                .help(color.description)
            }
        }
    }

    private var gradientPresetsGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 10) {
            ForEach(gradientPresets, id: \.name) { preset in
                Button(action: { apply(preset) }) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [preset.start.color, preset.end.color],
                                startPoint: .top, endPoint: .bottom))
                        .frame(height: 34)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.2)))
                }
                .buttonStyle(.plain)
                .help(preset.name)
            }
        }
    }

    private func apply(_ preset: GradientPreset) {
        state.gradientStart = preset.start
        state.gradientEnd = preset.end
        state.gradientAngle = preset.angle
    }
}

/// Rounded settings card with a bold title and optional monospaced subtitle,
/// styled like System Settings groups.
struct SectionCard<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
                Spacer()
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary.opacity(0.8))
                }
            }
            content
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.55))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.black.opacity(0.05)))
    }
}
