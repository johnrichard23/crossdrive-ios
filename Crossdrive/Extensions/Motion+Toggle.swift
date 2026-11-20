import DesignSystem
import SwiftUI

extension DesignSystem.Motion {
    /// The switch thumb, after transitions.dev "Toggle": it slides across with a
    /// double bounce. It runs 1 pt past the end at 55% of the time, settles at
    /// 80%, then rests. The track colour changes at once.
    enum Toggle {
        static let trackWidth: CGFloat = 51
        static let trackHeight: CGFloat = 31
        static let thumbSize: CGFloat = 27
        /// How far the thumb moves between off and on.
        static let travel: CGFloat = trackWidth - thumbSize - 4
        /// How far past the end the thumb goes on the way.
        static let overshoot: CGFloat = 1
        /// The whole slide, 350 ms.
        static let duration: TimeInterval = 0.35
        /// The first leg ends at 55% of the slide, the second at 80%.
        static let firstLeg: TimeInterval = duration * 0.55
        static let secondLeg: TimeInterval = duration * 0.25
        static let lastLeg: TimeInterval = duration * 0.20
        /// cubic-bezier(0.34, 1.35, 0.64, 1), applied to each leg as in the recipe.
        static let curve = UnitCurve.bezier(
            startControlPoint: UnitPoint(x: 0.34, y: 1.35),
            endControlPoint: UnitPoint(x: 0.64, y: 1)
        )

        /// Where the thumb is, relative to its end position, while it slides.
        /// It starts at the old end (`start`), runs `past` beyond the new end,
        /// then settles at 0.
        @KeyframesBuilder<CGFloat>
        static func slide(isOn: Bool) -> some Keyframes<CGFloat> {
            KeyframeTrack {
                MoveKeyframe(isOn ? -travel : travel)
                LinearKeyframe(
                    isOn ? overshoot : -overshoot,
                    duration: firstLeg,
                    timingCurve: curve
                )
                LinearKeyframe(0, duration: secondLeg, timingCurve: curve)
                LinearKeyframe(0, duration: lastLeg, timingCurve: curve)
            }
        }
    }
}
