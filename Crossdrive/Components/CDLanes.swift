import SwiftUI

/// The two-lane brand device: two thin rules, one above the other. Sits above
/// a section title or at the corner of a Pine card.
struct CDLanes: View {
    var width: CGFloat = 40
    var gap: CGFloat = 6
    var color: Color

    var body: some View {
        VStack(spacing: gap) {
            Rectangle().fill(color).frame(height: 2)
            Rectangle().fill(color).frame(height: 2)
        }
        .frame(width: width)
        .accessibilityHidden(true)
    }
}

#Preview {
    CDLanes(color: .purple).padding()
}
