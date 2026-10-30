import Vapor

struct CreateProductRequest: Content {
    let name: String
    let sku: String
}

struct ProductResponse: Content {
    let id: UUID
    let name: String
    let sku: String

    init(product: Product) throws {
        guard let id = product.id else {
            throw Abort(.internalServerError, reason: "Product ID is missing")
        }

        self.id = id
        self.name = product.name
        self.sku = product.sku
    }
}

struct ProductController {
    private let service = ProductService()

    func index(req: Request) async throws -> [ProductResponse] {
        let products = try await service.all(on: req.db)
        return try products.map { try ProductResponse(product: $0) }
    }

    func create(req: Request) async throws -> Response {
        let input = try req.content.decode(CreateProductRequest.self)

        let product = try await service.create(
            name: input.name,
            sku: input.sku,
            on: req.db
        )

        let response = try ProductResponse(product: product)
        return try await response.encodeResponse(status: .created, for: req)
    }

    func show(req: Request) async throws -> ProductResponse {
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid product ID")
        }

        let product = try await service.find(id: id, on: req.db)
        return try ProductResponse(product: product)
    }
}
