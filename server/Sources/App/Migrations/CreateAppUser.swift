import Fluent

struct CreateAppUser: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("app_users")
            .id()
            .field("email", .string, .required)
            .field("password_hash", .string, .required)
            .field("role", .string, .required)
            .field("created_at", .datetime, .required)
            .unique(on: "email")
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("app_users").delete()
    }
}
