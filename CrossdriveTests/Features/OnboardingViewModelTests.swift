@testable import Crossdrive
import XCTest

@MainActor
final class OnboardingViewModelTests: XCTestCase {
    func testAdvance_WhenNotOnTheLastPage_ShouldMoveToTheNextPage() {
        // Arrange
        let (viewModel, _) = makeViewModel(pageCount: 3)

        // Act
        viewModel.advance()

        // Assert
        XCTAssertEqual(viewModel.index, 1)
        XCTAssertFalse(viewModel.isFinished)
    }

    func testAdvance_WhenOnTheLastPage_ShouldFinish() {
        // Arrange
        let (viewModel, finished) = makeViewModel(pageCount: 3)
        viewModel.index = 2

        // Act
        viewModel.advance()

        // Assert
        XCTAssertTrue(viewModel.isLastPage)
        XCTAssertEqual(finished.values.count, 1)
    }

    func testIsLastPage_WhenOnTheFirstOfSeveral_ShouldBeFalse() {
        // Act
        let (viewModel, _) = makeViewModel(pageCount: 3)

        // Assert
        XCTAssertFalse(viewModel.isLastPage)
    }

    func testIsLastPage_WhenThereIsOnlyOnePage_ShouldBeTrue() {
        // Act
        let (viewModel, _) = makeViewModel(pageCount: 1)

        // Assert
        XCTAssertTrue(viewModel.isLastPage)
    }

    func testFinish_WhenSkippedFromTheFirstPage_ShouldFinish() {
        // Arrange
        let (viewModel, finished) = makeViewModel(pageCount: 3)

        // Act
        viewModel.finish()

        // Assert
        XCTAssertEqual(finished.values.count, 1)
    }

    func testFinish_WhenCalledTwice_ShouldReportOnlyOnce() {
        // Arrange: a double tap on Get started.
        let (viewModel, finished) = makeViewModel(pageCount: 3)
        viewModel.index = 2

        // Act
        viewModel.advance()
        viewModel.advance()

        // Assert
        XCTAssertEqual(finished.values.count, 1)
    }

    func testStart_WhenThereAreNoPages_ShouldFinishAtOnce() {
        // Arrange
        let (viewModel, finished) = makeViewModel(pageCount: 0)

        // Act
        viewModel.start()

        // Assert
        XCTAssertEqual(finished.values.count, 1)
    }

    func testStart_WhenThereArePages_ShouldStayOnTheFirstPage() {
        // Arrange
        let (viewModel, finished) = makeViewModel(pageCount: 3)

        // Act
        viewModel.start()

        // Assert
        XCTAssertTrue(finished.values.isEmpty)
        XCTAssertEqual(viewModel.index, 0)
    }

    private func makeViewModel(pageCount: Int) -> (OnboardingViewModel, Recorder<Bool>) {
        let finished = Recorder<Bool>()
        let pages = (0 ..< pageCount).map {
            OnboardingPage(id: "\($0)", systemImage: "circle", title: "Page", message: "Text")
        }
        return (OnboardingViewModel(pages: pages) { finished.add(true) }, finished)
    }
}
