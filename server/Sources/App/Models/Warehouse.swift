import Fluent
import Vapor

final class Warehouse: Model, Content, @unchecked Sendable {
    static let schema = "warehouses"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "code")
    var code: String

    @Field(key: "name")
    var name: String

    @Field(key: "address")
    var address: String

    @Field(key: "created_at")
    var createdAt: Date

    init() {}

    init(
        id: UUID? = nil,
        code: String,
        name: String,
        address: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.code = code
        self.name = name
        self.address = address
        self.createdAt = createdAt
    }
}
