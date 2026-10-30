import Fluent
import Vapor

final class StorageLocation: Model, Content, @unchecked Sendable {
    static let schema = "storage_locations"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "warehouse_id")
    var warehouse: Warehouse

    @Field(key: "code")
    var code: String

    @Field(key: "zone")
    var zone: String

    @Field(key: "details")
    var details: String

    @Field(key: "created_at")
    var createdAt: Date

    init() {}

    init(
        id: UUID? = nil,
        warehouseID: UUID,
        code: String,
        zone: String,
        details: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.$warehouse.id = warehouseID
        self.code = code
        self.zone = zone
        self.details = details
        self.createdAt = createdAt
    }
}
