import DesignSystem
import SwiftUI

extension DesignSystem.Motion {
    /// One slide of the thumb: where it starts relative to its end, and
    /// whether it gets the double bounce (a fresh flip) or the plain spring
    /// (a flip made while it was still moving).
    struct ToggleRun: Equatable {
        var isOn: Bool
        var from: CGFloat
        var bounces: Bool

        /// A thumb resting at its end.
        static func resting(isOn: Bool) -> ToggleRun {
            ToggleRun(isOn: isOn, from: 0, bounces: true)
        }
    }

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

        /// A flip made mid-slide glides back with this, matching `Motion.settle`.
        static let reversal = Spring(duration: 0.4, bounce: 0)

        /// The thumb's end position for each state.
        static func rest(isOn: Bool) -> CGFloat {
            isOn ? travel : 0
        }

        /// The run for a flip to `isOn`, made `elapsed` seconds into `current`.
        /// Mid-slide it starts from where the thumb is, so nothing jumps.
        static func run(
            after current: ToggleRun,
            to isOn: Bool,
            elapsed: TimeInterval
        ) -> ToggleRun {
            let timeline = KeyframeTimeline(initialValue: CGFloat.zero) { track(for: current) }
            // A bouncing thumb is already home for the last leg, so a flip then is fresh.
            let moving = current.bounces ? firstLeg + secondLeg : timeline.duration
            guard elapsed < moving else {
                return ToggleRun(isOn: isOn, from: isOn ? -travel : travel, bounces: true)
            }
            let position = rest(isOn: current.isOn) + timeline.value(time: elapsed)
            return ToggleRun(isOn: isOn, from: position - rest(isOn: isOn), bounces: false)
        }

        /// Where the thumb is, relative to its end position, while it slides. A
        /// fresh flip starts back at the old end (`travel` away), runs
        /// `overshoot` past the new end, then settles at 0.
        @KeyframesBuilder<CGFloat>
        static func slide(isOn: Bool) -> some Keyframes<CGFloat> {
            track(for: ToggleRun(isOn: isOn, from: isOn ? -travel : travel, bounces: true))
        }

        @KeyframesBuilder<CGFloat>
        static func track(for run: ToggleRun) -> some Keyframes<CGFloat> {
            KeyframeTrack {
                MoveKeyframe(run.from)
                if run.bounces {
                    LinearKeyframe(
                        run.isOn ? overshoot : -overshoot,
                        duration: firstLeg,
                        timingCurve: curve
                    )
                    LinearKeyframe(0, duration: secondLeg, timingCurve: curve)
                    LinearKeyframe(0, duration: lastLeg, timingCurve: curve)
                } else {
                    SpringKeyframe(0, spring: reversal)
                }
            }
        }
    }
}
