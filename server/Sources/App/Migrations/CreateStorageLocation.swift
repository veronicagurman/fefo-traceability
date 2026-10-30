import Fluent

struct CreateStorageLocation: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("storage_locations")
            .id()
            .field(
                "warehouse_id",
                .uuid,
                .required,
                .references("warehouses", "id", onDelete: .cascade)
            )
            .field("code", .string, .required)
            .field("zone", .string, .required)
            .field("details", .string, .required)
            .field("created_at", .datetime, .required)
            .unique(on: "warehouse_id", "code")
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("storage_locations").delete()
    }
}
