import Fluent

struct CreateBatchPlacement: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("batch_placements")
            .id()
            .field(
                "batch_id",
                .uuid,
                .required,
                .references("batches", "id", onDelete: .restrict)
            )
            .field(
                "storage_location_id",
                .uuid,
                .required,
                .references("storage_locations", "id", onDelete: .restrict)
            )
            .field("quantity", .int, .required)
            .field("created_at", .datetime, .required)
            .unique(on: "batch_id", "storage_location_id")
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("batch_placements").delete()
    }
}
