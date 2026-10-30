import Fluent
import Vapor

struct ProductService {
    func all(on db: Database) async throws -> [Product] {
        try await Product.query(on: db)
            .sort(\.$name)
            .all()
    }

    func create(name: String, sku: String, on db: Database) async throws -> Product {
        let product = Product(name: name, sku: sku)
        try await product.save(on: db)
        return product
    }

    func find(id: UUID, on db: Database) async throws -> Product {
        guard let product = try await Product.find(id, on: db) else {
            throw Abort(.notFound, reason: "Product not found")
        }
        return product
    }
}
