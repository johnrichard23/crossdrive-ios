import DesignSystem
import SwiftUI

/// The Harvest date stamp, e.g. "Dec 12 to 14". Once per screen at most.
struct CDDateStamp: View {
    let text: String

    var body: some View {
        Text(text)
            .textRole(.footnote, emphasized: true)
            .foregroundStyle(CDColor.onHarvest)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(CDColor.harvest, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
    }
}

#Preview {
    CDDateStamp(text: "Dec 12 to 14").padding()
}
