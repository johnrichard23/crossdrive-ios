import DesignSystem
import SwiftUI

/// My trip while it loads: grey blocks shaped like the real page (status,
/// banner, the Meet at card, the saved line, Up next).
struct MyTripSkeleton: View {
    @Environment(\.theme) private var theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                block(width: 180, height: 26, radius: 13)
                block(height: 52, radius: 12)
                block(height: 270, radius: 20)
                block(width: 260, height: 16, radius: 8)
                block(width: 100, height: 22, radius: 8)
                block(width: 220, height: 40, radius: 8)
            }
            .dsLoading(true)
            .screenMargins()
            .padding(.top, 8)
        }
        .scrollDisabled(true)
        .accessibilityLabel("Loading your trip")
    }

    private func block(width: CGFloat? = nil, height: CGFloat, radius: CGFloat) -> some View {
        DesignSystem.Radius.shape(radius)
            .fill(theme.surfacePressed)
            .frame(maxWidth: width ?? .infinity, alignment: .leading)
            .frame(height: height)
    }
}
