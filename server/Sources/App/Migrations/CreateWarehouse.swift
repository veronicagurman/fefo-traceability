import Fluent

struct CreateWarehouse: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("warehouses")
            .id()
            .field("code", .string, .required)
            .field("name", .string, .required)
            .field("address", .string, .required)
            .field("created_at", .datetime, .required)
            .unique(on: "code")
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("warehouses").delete()
    }
}
