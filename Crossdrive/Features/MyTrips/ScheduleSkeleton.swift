import DesignSystem
import SwiftUI

/// The schedule while it loads: grey day tabs, then rows shaped like the real
/// ones (a time beside a card with a title and a place).
struct ScheduleSkeleton: View {
    @Environment(\.theme) private var theme
    @ScaledMetric(relativeTo: .body) private var timeWidth: CGFloat = 58

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    ForEach(0 ..< 3, id: \.self) { _ in
                        block(height: 64, radius: 16)
                    }
                }
                VStack(spacing: 10) {
                    ForEach(0 ..< 4, id: \.self) { _ in row }
                }
            }
            .dsLoading(true)
            .screenMargins()
            .padding(.top, 8)
        }
        .scrollDisabled(true)
        .accessibilityLabel("Loading the schedule")
    }

    private var row: some View {
        HStack(alignment: .top, spacing: 8) {
            block(width: 40, height: 18, radius: 6)
                .padding(.top, 12)
                .frame(width: timeWidth, alignment: .leading)
            VStack(alignment: .leading, spacing: 8) {
                block(height: 18, radius: 6)
                    .containerRelativeFrame(.horizontal, alignment: .leading) { width, _ in
                        width * 0.5
                    }
                block(height: 14, radius: 6)
                    .containerRelativeFrame(.horizontal, alignment: .leading) { width, _ in
                        width * 0.32
                    }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.surface, in: DesignSystem.Radius.shape(16))
            .overlay(DesignSystem.Radius.shape(16).stroke(theme.separator, lineWidth: 1))
        }
    }

    private func block(width: CGFloat? = nil, height: CGFloat, radius: CGFloat) -> some View {
        DesignSystem.Radius.shape(radius)
            .fill(theme.surfacePressed)
            .frame(maxWidth: width ?? .infinity)
            .frame(width: width, height: height)
    }
}

#Preview {
    ScheduleSkeleton().theme(.crossdrive)
}
