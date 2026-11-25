import DesignSystem
import SwiftUI

/// The app's switch: a label with a CrossDrive switch on the right, whose thumb
/// slides with the double bounce from `Motion.Toggle`. Set once at the root, so
/// every `Toggle` uses it.
struct CDToggleStyle: ToggleStyle {
    @Environment(\.theme) private var theme
    @Environment(\.layoutDirection) private var layoutDirection
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
        typealias Slide = DesignSystem.Motion.Toggle
        let rest = isOn ? Slide.travel : 0
        // The thumb is placed at its end position at once; the animator then
        // carries it from where it was to there, with the double bounce.
        return Capsule()
            .fill(isOn ? theme.accent : theme.surfacePressed)
            .frame(width: Slide.trackWidth, height: Slide.trackHeight)
            .overlay(alignment: .leading) {
                Circle()
                    .fill(Color.white)
                    .frame(width: Slide.thumbSize, height: Slide.thumbSize)
                    .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
                    .padding(2)
                    .keyframeAnimator(initialValue: CGFloat.zero, trigger: isOn) { thumb, delta in
                        // Right-to-left layouts slide the other way.
                        let direction: CGFloat = layoutDirection == .rightToLeft ? -1 : 1
                        thumb.offset(x: direction * (rest + (reduceMotion ? 0 : delta)))
                    } keyframes: { _ in
                        Slide.slide(isOn: isOn)
                    }
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
