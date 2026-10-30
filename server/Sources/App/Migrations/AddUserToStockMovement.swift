import Fluent

struct AddUserToStockMovement: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("stock_movements")
            .field(
                "user_id",
                .uuid,
                .references("app_users", "id", onDelete: .restrict)
            )
            .update()
    }

    func revert(on database: Database) async throws {
        try await database.schema("stock_movements")
            .deleteField("user_id")
            .update()
    }
}
