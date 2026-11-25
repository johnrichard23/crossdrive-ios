import DesignSystem
import SwiftUI

/// Numbered stops on a line: done steps get a check, the current one a filled
/// number, the rest an outline. `DSStepIndicator` is a bar and would not
/// name the steps.
struct CDStepRow: View {
    let titles: [String]
    /// 0-based.
    let current: Int

    @Environment(\.theme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private static let dot: CGFloat = 26

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(titles.indices, id: \.self) { index in
                VStack(spacing: 4) {
                    dot(for: index)
                    if !dynamicTypeSize.isAccessibilitySize {
                        Text(titles[index])
                            .textRole(.caption1, emphasized: index <= current)
                            .foregroundStyle(color(for: index))
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .background(alignment: .top) { line }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Step \(current + 1) of \(titles.count): \(titles[current])"))
    }

    /// The grey line between the first and last dot, purple up to the current one.
    private var line: some View {
        GeometryReader { proxy in
            let slot = proxy.size.width / CGFloat(max(titles.count, 1))
            let full = slot * CGFloat(titles.count - 1)
            ZStack(alignment: .leading) {
                Rectangle().fill(theme.border).frame(width: full)
                Rectangle().fill(theme.accent).frame(width: slot * CGFloat(current))
            }
            .frame(height: 2)
            .offset(x: slot / 2, y: Self.dot / 2 - 1)
        }
        .frame(height: Self.dot)
    }

    private func dot(for index: Int) -> some View {
        ZStack {
            if index < current {
                Circle().fill(theme.accent)
                DSIcon(.check, role: .caption1).foregroundStyle(theme.onAccent)
            } else if index == current {
                Circle().fill(theme.accent)
                Text("\(index + 1)")
                    .textRole(.footnote, emphasized: true)
                    .foregroundStyle(theme.onAccent)
            } else {
                Circle().fill(theme.background)
                Circle().strokeBorder(theme.border, lineWidth: 1.5)
                Text("\(index + 1)")
                    .textRole(.footnote, emphasized: true)
                    .foregroundStyle(theme.labelSecondary)
            }
        }
        .frame(width: Self.dot, height: Self.dot)
    }

    private func color(for index: Int) -> Color {
        if index < current {
            return theme.accent
        }
        return index == current ? theme.labelPrimary : theme.labelSecondary
    }
}

#Preview {
    CDStepRow(titles: ["Role", "Details", "Waiver", "Done"], current: 1)
        .padding()
        .theme(.crossdrive)
}
