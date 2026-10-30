import Fluent

struct CreateAuthToken: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("auth_tokens")
            .id()
            .field(
                "user_id",
                .uuid,
                .required,
                .references("app_users", "id", onDelete: .cascade)
            )
            .field("token_hash", .string, .required)
            .field("expires_at", .datetime, .required)
            .unique(on: "token_hash")
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("auth_tokens").delete()
    }
}
