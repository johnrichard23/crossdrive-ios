@testable import Crossdrive
import XCTest

final class RegistrationFormTests: XCTestCase {
    func testNormalized_ForEachCase_ShouldGiveElevenDigitsFrom09OrNil() {
        // Arrange
        let cases: [(typed: String, expected: String?)] = [
            ("0917 555 0142", "09175550142"),
            ("0917-555-0142", "09175550142"),
            ("+63 917 555 0142", "09175550142"),
            ("639175550142", "09175550142"),
            ("0917 555 01", nil),
            ("091755501420", nil),
            ("0817 555 0142", nil),
            ("", nil),
        ]

        for item in cases {
            // Act
            let normalized = PhilippineMobile.normalized(item.typed)

            // Assert
            XCTAssertEqual(normalized, item.expected, "typed: \(item.typed)")
        }
    }

    func testProblem_WhenTheNumberIsShort_ShouldSayToEnterAllElevenDigits() {
        // Act
        let problem = PhilippineMobile.problem(with: "0917 555 01")

        // Assert
        XCTAssertEqual(problem, "This number is too short. Enter all 11 digits, starting with 09.")
    }

    func testSteps_ForATripAndACamp_ShouldSkipTheRoleStepForCamps() {
        // Act
        let trip = RegistrationStep.steps(for: .trip)
        let camp = RegistrationStep.steps(for: .camp)

        // Assert
        XCTAssertEqual(trip, [.role, .details, .waiver, .done])
        XCTAssertEqual(camp, [.details, .waiver, .done])
    }

    func testErrors_WhenDetailsAreEmpty_ShouldFlagMobileAndEmergencyContact() {
        // Arrange
        let form = RegistrationForm()

        // Act
        let errors = form.errors(on: .details, kind: .trip)

        // Assert
        XCTAssertEqual(Set(errors.keys), [.mobile, .emergencyName, .emergencyMobile])
    }

    func testErrors_WhenDetailsAreFilledIn_ShouldBeEmpty() {
        // Arrange
        let form = Self.filledForm()

        // Act
        let errors = form.errors(on: .details, kind: .trip)

        // Assert
        XCTAssertTrue(errors.isEmpty)
    }

    func testErrors_WhenAMinorOnATripHasNoGuardian_ShouldAskForTheGuardian() {
        // Arrange
        var form = Self.filledForm()
        form.isMinor = true

        // Act
        let errors = form.errors(on: .waiver, kind: .trip)

        // Assert
        XCTAssertEqual(Set(errors.keys), [.guardianName, .guardianMobile])
    }

    func testErrors_WhenACampHasNoPermit_ShouldNotAskForOne() {
        // Arrange
        let form = Self.filledForm()

        // Act
        let errors = form.errors(on: .waiver, kind: .camp)

        // Assert
        XCTAssertTrue(errors.isEmpty, "the camp permit is optional")
    }

    func testErrors_WhenACampPermitIsHalfFilledIn_ShouldAskForTheRest() {
        // Arrange
        var form = Self.filledForm()
        form.guardianName = "Maria Bañares"

        // Act
        let errors = form.errors(on: .waiver, kind: .camp)

        // Assert
        XCTAssertEqual(Set(errors.keys), [.guardianMobile])
    }

    func testErrors_WhenNotSigned_ShouldAskForTheSignature() {
        // Arrange
        var form = Self.filledForm()
        form.signature = "   "

        // Act
        let errors = form.errors(on: .waiver, kind: .trip)

        // Assert
        XCTAssertEqual(errors[.signature], "Type your full name to sign the waiver.")
    }

    static func filledForm() -> RegistrationForm {
        var form = RegistrationForm()
        form.role = .anywhere
        form.mobile = "0917 555 0142"
        form.emergencyName = "Liza Bañares"
        form.emergencyMobile = "0917 555 0199"
        form.signature = "Joy Bañares"
        return form
    }
}
