import DesignSystem
import SwiftUI

/// A large display line (the countdown number, a film quote) in the brand's
/// display face at a size the type scale has no role for. It still scales with
/// the reader's text size, like the roles do.
struct CDDisplayText: ViewModifier {
    let size: CGFloat
    let lineHeight: CGFloat
    let tracking: CGFloat
    /// One line that takes exactly `lineHeight`, like a CSS line box.
    let singleLine: Bool

    @Environment(\.theme) private var theme
    @ScaledMetric private var scale: CGFloat = 1

    func body(content: Content) -> some View {
        let name = theme.typeface.display?.bold ?? "Outfit-Bold"
        let pointSize = size * min(scale, 1.6)
        let natural = UIFont(name: name, size: pointSize)?.lineHeight ?? pointSize * 1.2
        let text = content
            .font(.custom(name, fixedSize: pointSize))
            .tracking(tracking * min(scale, 1.6))
            .lineSpacing(lineHeight * min(scale, 1.6) - natural)
        if singleLine {
            text.frame(height: lineHeight * min(scale, 1.6), alignment: .center)
        } else {
            text
        }
    }
}

extension View {
    /// Large display text: `size` and `lineHeight` in points at the default text size.
    func csDisplay(
        size: CGFloat,
        lineHeight: CGFloat,
        tracking: CGFloat = 0,
        singleLine: Bool = false
    ) -> some View {
        modifier(CDDisplayText(
            size: size,
            lineHeight: lineHeight,
            tracking: tracking,
            singleLine: singleLine
        ))
    }
}
