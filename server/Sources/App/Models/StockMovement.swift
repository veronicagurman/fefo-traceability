import Fluent
import Vapor

final class StockMovement: Model, Content, @unchecked Sendable {
    static let schema = "stock_movements"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "batch_id")
    var batch: Batch

    @OptionalParent(key: "user_id")
    var user: AppUser?

    @OptionalParent(key: "from_location_id")
    var fromLocation: StorageLocation?

    @OptionalParent(key: "to_location_id")
    var toLocation: StorageLocation?

    @Field(key: "quantity")
    var quantity: Int

    @Field(key: "operation_type")
    var operationType: String

    @Field(key: "created_at")
    var createdAt: Date

    init() {}

    init(
        id: UUID? = nil,
        batchID: UUID,
        userID: UUID? = nil,
        fromLocationID: UUID? = nil,
        toLocationID: UUID? = nil,
        quantity: Int,
        operationType: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.$batch.id = batchID
        self.$user.id = userID
        self.$fromLocation.id = fromLocationID
        self.$toLocation.id = toLocationID
        self.quantity = quantity
        self.operationType = operationType
        self.createdAt = createdAt
    }
}
