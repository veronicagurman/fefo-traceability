import Fluent
import Vapor

final class Product: Model, Content, @unchecked Sendable {
    static let schema = "products"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "name")
    var name: String

    @Field(key: "sku")
    var sku: String

    init() {}

    init(id: UUID? = nil, name: String, sku: String) {
        self.id = id
        self.name = name
        self.sku = sku
    }
}
