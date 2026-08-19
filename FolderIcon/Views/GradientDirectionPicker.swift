import SwiftUI

/// Horizontal row of 8 arrow buttons for the gradient direction.
/// Arrows point where the gradient flows (→ = 0°, ↗ = 45°, ↑ = 90°...).
/// Ordered clockwise starting from the left.
struct GradientDirectionPicker: View {
    @Binding var angle: Double

    private struct Cell: Identifiable {
        let id: Int
        let arrow: String
        let angle: Double
    }

    private let cells: [Cell] = [
        Cell(id: 0, arrow: "arrow.left", angle: 180),
        Cell(id: 1, arrow: "arrow.up.left", angle: 135),
        Cell(id: 2, arrow: "arrow.up", angle: 90),
        Cell(id: 3, arrow: "arrow.up.right", angle: 45),
        Cell(id: 4, arrow: "arrow.right", angle: 0),
        Cell(id: 5, arrow: "arrow.down.right", angle: 315),
        Cell(id: 6, arrow: "arrow.down", angle: 270),
        Cell(id: 7, arrow: "arrow.down.left", angle: 225),
    ]

    /// The arrow that matches the current angle (within a small tolerance),
    /// or nil if the angle is between two arrows.
    private var activeStepAngle: Double? {
        let normalized = angle.truncatingRemainder(dividingBy: 360)
        let rounded = (normalized / 45).rounded() * 45
        return abs(normalized - rounded) < 0.75 ? rounded : nil
    }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(cells) { cell in
                arrowButton(cell)
            }
        }
    }

    private func arrowButton(_ cell: Cell) -> some View {
        let isActive = activeStepAngle == cell.angle
        return Button(action: { angle = cell.angle }) {
            Image(systemName: cell.arrow)
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 30, height: 30)
                .background(isActive ? Color.blue.opacity(0.15) : Color.gray.opacity(0.08))
                .cornerRadius(8)
                .foregroundColor(isActive ? .blue : .secondary)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isActive ? Color.blue : Color.clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .help("\(Int(cell.angle))°")
    }
}
