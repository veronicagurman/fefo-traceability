import Fluent

struct CreateStockMovement: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("stock_movements")
            .id()
            .field(
                "batch_id",
                .uuid,
                .required,
                .references("batches", "id", onDelete: .restrict)
            )
            .field(
                "from_location_id",
                .uuid,
                .references("storage_locations", "id", onDelete: .restrict)
            )
            .field(
                "to_location_id",
                .uuid,
                .references("storage_locations", "id", onDelete: .restrict)
            )
            .field("quantity", .int, .required)
            .field("operation_type", .string, .required)
            .field("created_at", .datetime, .required)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("stock_movements").delete()
    }
}
