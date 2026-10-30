import Fluent
import Vapor

final class Batch: Model, Content, @unchecked Sendable {
    static let schema = "batches"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "product_id")
    var product: Product

    @Field(key: "batch_number")
    var batchNumber: String

    @Field(key: "quantity")
    var quantity: Int

    @Field(key: "received_at")
    var receivedAt: Date

    @Field(key: "expires_at")
    var expiresAt: Date

    init() {}

    init(
        id: UUID? = nil,
        productID: UUID,
        batchNumber: String,
        quantity: Int,
        receivedAt: Date,
        expiresAt: Date
    ) {
        self.id = id
        self.$product.id = productID
        self.batchNumber = batchNumber
        self.quantity = quantity
        self.receivedAt = receivedAt
        self.expiresAt = expiresAt
    }
}
