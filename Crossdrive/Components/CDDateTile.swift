import DesignSystem
import SwiftUI

/// The first day of an event as a small Harvest tile: "12" over "DEC". The one
/// gold on its screen.
struct CDDateTile: View {
    let day: String
    let month: String
    /// The month in full, for VoiceOver. Defaults to `month`.
    var spokenMonth: String?

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            Text(day).textRole(.headline, emphasized: true)
            Text(month.uppercased())
                .textRole(.caption2, emphasized: true)
                .tracking(0.8)
        }
        .foregroundStyle(CDColor.onHarvest)
        .frame(minWidth: 48, minHeight: 48)
        .padding(.horizontal, 2)
        .background(CDColor.harvest, in: DesignSystem.Radius.shape(14))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(spokenMonth ?? month) \(day)"))
    }
}

#Preview {
    CDDateTile(day: "12", month: "Dec").padding()
}
