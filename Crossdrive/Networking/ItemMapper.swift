import DataLayer

/// The only place `ItemDTO` and `Item` meet.
struct ItemMapper: Mapper {
    func model(from dto: ItemDTO) throws -> Item {
        guard let id = dto.id, !id.isEmpty else { throw MappingError.missingField("id") }
        return Item(
            id: id,
            title: dto.title ?? "Untitled",
            summary: dto.summary ?? "",
            isFavorite: dto.isFavorite ?? false
        )
    }

    func dto(from model: Item) throws -> ItemDTO {
        ItemDTO(
            id: model.id,
            title: model.title,
            summary: model.summary,
            isFavorite: model.isFavorite
        )
    }
}
