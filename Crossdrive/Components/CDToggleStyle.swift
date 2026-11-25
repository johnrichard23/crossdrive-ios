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
        return Capsule()
            .fill(isOn ? theme.accent : theme.surfacePressed)
            .frame(width: Slide.trackWidth, height: Slide.trackHeight)
            .overlay(alignment: .leading) {
                SwitchThumb(
                    isOn: isOn,
                    layoutDirection: layoutDirection,
                    reduceMotion: reduceMotion
                )
            }
    }
}

/// The thumb. Each flip starts a new run: the double bounce from rest, or a
/// plain spring from where it is when flipped back mid-slide.
private struct SwitchThumb: View {
    typealias Slide = DesignSystem.Motion.Toggle

    let isOn: Bool
    let layoutDirection: LayoutDirection
    let reduceMotion: Bool

    @State private var run: DesignSystem.Motion.ToggleRun
    @State private var startedAt = Date.distantPast

    init(isOn: Bool, layoutDirection: LayoutDirection, reduceMotion: Bool) {
        self.isOn = isOn
        self.layoutDirection = layoutDirection
        self.reduceMotion = reduceMotion
        _run = State(initialValue: .resting(isOn: isOn))
    }

    var body: some View {
        Circle()
            .fill(Color.white)
            .frame(width: Slide.thumbSize, height: Slide.thumbSize)
            .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
            .padding(2)
            .keyframeAnimator(initialValue: CGFloat.zero, trigger: run) { thumb, delta in
                // Right-to-left layouts slide the other way.
                let direction: CGFloat = layoutDirection == .rightToLeft ? -1 : 1
                let rest = Slide.rest(isOn: run.isOn)
                thumb.offset(x: direction * (rest + (reduceMotion ? 0 : delta)))
            } keyframes: { _ in
                Slide.track(for: run)
            }
            .onChange(of: isOn) { _, isOn in
                let now = Date.now
                run = Slide.run(after: run, to: isOn, elapsed: now.timeIntervalSince(startedAt))
                startedAt = now
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
