import DesignSystem
import SwiftUI

/// The app's switch: a label with a CrossDrive switch on the right. The thumb
/// slides with the package's `settle` motion, and not at all under Reduce Motion.
/// Set once at the root, so every `Toggle` uses it.
struct CDToggleStyle: ToggleStyle {
    private static let trackWidth: CGFloat = 51
    private static let trackHeight: CGFloat = 31
    private static let thumbSize: CGFloat = 27
    private static let inset: CGFloat = 2

    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(spacing: 12) {
                configuration.label
                Spacer(minLength: 0)
                switchView(isOn: configuration.isOn)
            }
            .frame(minHeight: DesignSystem.minTapTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(SwitchPressStyle())
        .dsHaptic(.selection, trigger: configuration.isOn)
        // VoiceOver and Switch Control see a normal switch. The system style is
        // named so this Toggle does not pick up the app's style again.
        .accessibilityRepresentation {
            Toggle(isOn: configuration.$isOn) { configuration.label }
                .toggleStyle(.automatic)
        }
    }

    private func switchView(isOn: Bool) -> some View {
        let travel = Self.trackWidth - Self.thumbSize - 2 * Self.inset
        return Capsule()
            .fill(isOn ? theme.accent : theme.surfacePressed)
            .animation(DesignSystem.Motion.enter, value: isOn)
            .frame(width: Self.trackWidth, height: Self.trackHeight)
            .overlay(alignment: .leading) {
                Circle()
                    .fill(.white)
                    .frame(width: Self.thumbSize, height: Self.thumbSize)
                    .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
                    .padding(Self.inset)
                    .offset(x: isOn ? travel : 0)
                    // Movement: none under Reduce Motion. The colour fade above stays.
                    .animation(reduceMotion ? nil : DesignSystem.Motion.settle, value: isOn)
            }
    }
}

/// No dimming while pressed: the switch answers by sliding, not by fading.
private struct SwitchPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
    }
}

extension ToggleStyle where Self == CDToggleStyle {
    /// The app's switch.
    static var crossdrive: CDToggleStyle {
        CDToggleStyle()
    }
}

#Preview {
    @Previewable @State var isOn = false
    Toggle("Notifications", isOn: $isOn)
        .toggleStyle(.crossdrive)
        .padding()
        .theme(.crossdrive)
}
