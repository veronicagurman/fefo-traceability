import Fluent
import Vapor

struct StorageLocationService {
    func all(on db: Database) async throws -> [StorageLocation] {
        try await StorageLocation.query(on: db)
            .sort(\.$code, .ascending)
            .all()
    }

    func create(
        warehouseID: UUID,
        code: String,
        zone: String,
        details: String,
        on db: Database
    ) async throws -> StorageLocation {
        let code = code.trimmingCharacters(in: .whitespacesAndNewlines)
        let zone = zone.trimmingCharacters(in: .whitespacesAndNewlines)
        let details = details.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !code.isEmpty, !zone.isEmpty, !details.isEmpty else {
            throw Abort(.badRequest, reason: "Code, zone and details are required")
        }

        guard try await Warehouse.find(warehouseID, on: db) != nil else {
            throw Abort(.notFound, reason: "Warehouse not found")
        }

        let existing = try await StorageLocation.query(on: db)
            .filter(\.$warehouse.$id == warehouseID)
            .filter(\.$code == code)
            .first()

        guard existing == nil else {
            throw Abort(.conflict, reason: "Location code already exists in this warehouse")
        }

        let location = StorageLocation(
            warehouseID: warehouseID,
            code: code,
            zone: zone,
            details: details
        )

        try await location.save(on: db)
        return location
    }
}
