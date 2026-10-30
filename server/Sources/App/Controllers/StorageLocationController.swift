import Vapor

struct CreateStorageLocationRequest: Content {
    let warehouseID: UUID
    let code: String
    let zone: String
    let details: String
}

struct StorageLocationController {
    private let service = StorageLocationService()

    func index(req: Request) async throws -> [StorageLocation] {
        try await service.all(on: req.db)
    }

    func create(req: Request) async throws -> Response {
        let input = try req.content.decode(CreateStorageLocationRequest.self)

        let location = try await service.create(
            warehouseID: input.warehouseID,
            code: input.code,
            zone: input.zone,
            details: input.details,
            on: req.db
        )

        return try await location.encodeResponse(
            status: .created,
            for: req
        )
    }
}
