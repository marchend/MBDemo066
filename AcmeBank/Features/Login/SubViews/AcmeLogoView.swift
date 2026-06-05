import SwiftUI

/// A dark-navy hexagonal badge with a white "A" overlay — the Acme Bank logo mark.
struct AcmeLogoView: View {
    var size: CGFloat = 80

    var body: some View {
        ZStack {
            HexagonShape()
                .fill(Color.acmeNavy)
                .frame(width: size, height: size)

            Text("A")
                .font(.system(size: size * 0.42, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .accessibilityLabel("Acme Bank logo")
    }
}

// MARK: - Hexagon shape

/// A regular hexagon with a flat top.
private struct HexagonShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let centre = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let angleOffset = -CGFloat.pi / 2  // start at top

        for i in 0 ..< 6 {
            let angle = angleOffset + CGFloat(i) * (2 * .pi / 6)
            let x = centre.x + radius * cos(angle)
            let y = centre.y + radius * sin(angle)
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        path.closeSubpath()
        return path
    }
}

#Preview {
    AcmeLogoView()
        .padding()
}
