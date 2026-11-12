@testable import Crossdrive
import DataLayer
import XCTest

final class ItemMapperTests: XCTestCase {
    private let mapper = ItemMapper()

    func testModel_WhenOptionalFieldsAreMissing_ShouldUseDefaults() throws {
        // Arrange
        let dto = ItemDTO(id: "1")

        // Act
        let item = try mapper.model(from: dto)

        // Assert
        XCTAssertEqual(item, Item(id: "1", title: "Untitled", summary: "", isFavorite: false))
    }

    func testModel_WhenIDIsMissing_ShouldThrowMissingField() {
        // Act and Assert
        XCTAssertThrowsError(try mapper.model(from: ItemDTO(title: "No id"))) { error in
            XCTAssertEqual(error as? MappingError, .missingField("id"))
        }
    }

    func testModel_WhenIDIsEmpty_ShouldThrowMissingField() {
        // Act and Assert
        XCTAssertThrowsError(try mapper.model(from: ItemDTO(id: ""))) { error in
            XCTAssertEqual(error as? MappingError, .missingField("id"))
        }
    }

    func testDTO_WhenMappedBackAndForth_ShouldKeepTheItem() throws {
        // Arrange
        let item = Item(id: "7", title: "Lamp", summary: "Warm", isFavorite: true)

        // Act
        let result = try mapper.model(from: mapper.dto(from: item))

        // Assert
        XCTAssertEqual(result, item)
    }
}
