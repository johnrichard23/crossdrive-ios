import DesignSystem
import SwiftUI

extension View {
    /// Shakes the view sideways once each time `trigger` changes, to point at
    /// the field that needs fixing. Movement only: the error colour and message
    /// stay the caller's. Off under Reduce Motion.
    func errorShake(trigger: some Equatable) -> some View {
        modifier(ErrorShakeModifier(trigger: trigger))
    }
}

private typealias Shake = DesignSystem.Motion.Shake

private struct ErrorShakeModifier<Trigger: Equatable>: ViewModifier {
    let trigger: Trigger

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.keyframeAnimator(initialValue: CGFloat.zero, trigger: trigger) { view, offset in
            view.offset(x: reduceMotion ? 0 : offset)
        } keyframes: { _ in
            KeyframeTrack(\CGFloat.self) {
                LinearKeyframe(Shake.distance, duration: Shake.longLeg, timingCurve: Shake.curve)
                LinearKeyframe(-Shake.distance, duration: Shake.longLeg, timingCurve: Shake.curve)
                LinearKeyframe(Shake.overshoot, duration: Shake.shortLeg, timingCurve: Shake.curve)
                LinearKeyframe(CGFloat.zero, duration: Shake.shortLeg, timingCurve: Shake.curve)
            }
        }
    }
}

#Preview {
    @Previewable @State var attempts = 0
    VStack(spacing: 16) {
        Text("That password doesn't match.")
            .padding()
            .background(.red.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
            .errorShake(trigger: attempts)
        Button("Try") { attempts += 1 }
    }
    .padding()
}
