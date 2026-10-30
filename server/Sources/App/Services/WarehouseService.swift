import Fluent
import Vapor

struct WarehouseService {
    func all(on db: Database) async throws -> [Warehouse] {
        try await Warehouse.query(on: db)
            .sort(\.$name, .ascending)
            .all()
    }

    func create(
        code: String,
        name: String,
        address: String,
        on db: Database
    ) async throws -> Warehouse {
        let code = code.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let address = address.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !code.isEmpty, !name.isEmpty, !address.isEmpty else {
            throw Abort(.badRequest, reason: "Code, name and address are required")
        }

        let existing = try await Warehouse.query(on: db)
            .filter(\.$code == code)
            .first()

        guard existing == nil else {
            throw Abort(.conflict, reason: "Warehouse code already exists")
        }

        let warehouse = Warehouse(
            code: code,
            name: name,
            address: address
        )

        try await warehouse.save(on: db)
        return warehouse
    }
}
