import SwiftUI

/// Custom gradient slider without a system track.
struct HSBSlider: View {
    @Binding var value: Double
    let gradient: Gradient

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                LinearGradient(gradient: gradient, startPoint: .leading, endPoint: .trailing)
                    .frame(height: 24)
                    .cornerRadius(12)

                Circle()
                    .fill(Color.white)
                    .frame(width: 20, height: 20)
                    .shadow(radius: 2)
                    .offset(x: (CGFloat(value) * (geometry.size.width - 24.0)) + 2.0)
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        let newValue = Double(gesture.location.x / geometry.size.width)
                        value = max(0, min(1, newValue))
                    }
            )
        }
        .frame(height: 24)
    }
}
