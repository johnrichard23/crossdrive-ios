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
}
