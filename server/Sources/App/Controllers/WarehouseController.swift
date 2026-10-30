import Vapor

struct CreateWarehouseRequest: Content {
    let code: String
    let name: String
    let address: String
}

struct WarehouseController {
    private let service = WarehouseService()

    func index(req: Request) async throws -> [Warehouse] {
        try await service.all(on: req.db)
    }

    func create(req: Request) async throws -> Response {
        let input = try req.content.decode(CreateWarehouseRequest.self)

        let warehouse = try await service.create(
            code: input.code,
            name: input.name,
            address: input.address,
            on: req.db
        )

        return try await warehouse.encodeResponse(
            status: .created,
            for: req
        )
    }
}
