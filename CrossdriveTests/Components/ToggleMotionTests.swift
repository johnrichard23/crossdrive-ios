@testable import Crossdrive
import DesignSystem
import SwiftUI
import XCTest

final class ToggleMotionTests: XCTestCase {
    private typealias Slide = DesignSystem.Motion.Toggle

    func testSlide_WhenTurnedOn_ShouldRunPastTheEndThenSettleAtZero() {
        // Arrange
        let timeline = KeyframeTimeline(initialValue: CGFloat.zero) { Slide.slide(isOn: true) }
        let steps = stride(from: 0.0, through: Slide.duration, by: 0.005)

        // Act
        let positions = steps.map { timeline.value(time: $0) }

        // Assert: starts at the old end, passes the new end, ends on it.
        XCTAssertEqual(positions.first ?? 0, -Slide.travel, accuracy: 0.01)
        XCTAssertGreaterThan(positions.max() ?? 0, 0.5, "the thumb should run past the end")
        XCTAssertEqual(positions.last ?? 1, 0, accuracy: 0.01)
        XCTAssertEqual(timeline.duration, Slide.duration, accuracy: 0.001)
    }

    func testSlide_WhenTurnedOff_ShouldRunPastTheEndThenSettleAtZero() {
        // Arrange
        let timeline = KeyframeTimeline(initialValue: CGFloat.zero) { Slide.slide(isOn: false) }
        let positions = stride(from: 0.0, through: Slide.duration, by: 0.005)
            .map { timeline.value(time: $0) }

        // Assert
        XCTAssertEqual(positions.first ?? 0, Slide.travel, accuracy: 0.01)
        XCTAssertLessThan(positions.min() ?? 0, -0.5, "the thumb should run past the end")
        XCTAssertEqual(positions.last ?? 1, 0, accuracy: 0.01)
    }

    func testRun_WhenFlippedBackMidSlide_ShouldStartWhereTheThumbIsAndSpringHome() {
        // Arrange: turned on, then off again 100 ms in.
        let turnedOn = Slide.run(after: .resting(isOn: false), to: true, elapsed: 10)
        let onTimeline = KeyframeTimeline(initialValue: CGFloat.zero) { Slide.track(for: turnedOn) }
        let thumbNow = Slide.rest(isOn: true) + onTimeline.value(time: 0.1)

        // Act
        let turnedOff = Slide.run(after: turnedOn, to: false, elapsed: 0.1)
        let offTimeline = KeyframeTimeline(initialValue: CGFloat.zero) {
            Slide.track(for: turnedOff)
        }

        // Assert: no jump, no bounce, ends at rest.
        XCTAssertTrue(turnedOn.bounces)
        XCTAssertFalse(turnedOff.bounces)
        XCTAssertEqual(
            Slide.rest(isOn: false) + offTimeline.value(time: 0),
            thumbNow,
            accuracy: 0.01
        )
        XCTAssertEqual(offTimeline.value(time: offTimeline.duration), 0, accuracy: 0.01)
    }

    func testRun_WhenFlippedAfterTheSlideEnds_ShouldBounceFromTheOldEnd() {
        // Arrange
        let turnedOn = Slide.run(after: .resting(isOn: false), to: true, elapsed: 10)

        // Act
        let turnedOff = Slide.run(after: turnedOn, to: false, elapsed: Slide.duration + 0.01)

        // Assert
        XCTAssertTrue(turnedOff.bounces)
        XCTAssertEqual(turnedOff.from, Slide.travel, accuracy: 0.01)
    }
}
