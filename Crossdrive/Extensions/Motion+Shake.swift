import DesignSystem
import SwiftUI

extension DesignSystem.Motion {
    /// The error shake, after transitions.dev "Error state shake": right, left,
    /// a smaller right, then rest. 280 ms in all, each leg on the same soft
    /// ease-out curve.
    enum Shake {
        /// How far the field moves on the first two legs.
        static let distance: CGFloat = 6
        /// The smaller third leg, so the shake settles instead of stopping hard.
        static let overshoot: CGFloat = 4
        /// The first two legs (to the right, then to the left).
        static let longLeg: TimeInterval = 0.08
        /// The last two legs (the overshoot, then back to rest).
        static let shortLeg: TimeInterval = 0.06
        /// cubic-bezier(0.22, 1, 0.36, 1)
        static let curve = UnitCurve.bezier(
            startControlPoint: UnitPoint(x: 0.22, y: 1),
            endControlPoint: UnitPoint(x: 0.36, y: 1)
        )
    }
}
