import Fluent
import Vapor
import SQLKit

struct AddRemainingQuantityToBatch: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("batches")
            .field("remaining_quantity", .int)
            .update()

        guard let sql = database as? any SQLDatabase else {
            throw Abort(.internalServerError, reason: "SQL database is required")
        }

        try await sql.raw("""
            UPDATE batches
            SET remaining_quantity = quantity
            WHERE remaining_quantity IS NULL
            """).run()

        try await sql.raw("""
            ALTER TABLE batches
            ALTER COLUMN remaining_quantity SET NOT NULL
            """).run()
    }

    func revert(on database: Database) async throws {
        try await database.schema("batches")
            .deleteField("remaining_quantity")
            .update()
    }
}
