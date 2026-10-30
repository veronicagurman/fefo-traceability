import Fluent

struct CreateBatch: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("batches")
            .id()
            .field(
                "product_id",
                .uuid,
                .required,
                .references("products", "id", onDelete: .restrict)
            )
            .field("batch_number", .string, .required)
            .field("quantity", .int, .required)
            .field("received_at", .datetime, .required)
            .field("expires_at", .datetime, .required)
            .unique(on: "batch_number")
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("batches").delete()
    }
}

