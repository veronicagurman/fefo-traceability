import Fluent
import Vapor

final class BatchPlacement: Model, Content, @unchecked Sendable {
    static let schema = "batch_placements"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "batch_id")
    var batch: Batch

    @Parent(key: "storage_location_id")
    var storageLocation: StorageLocation

    @Field(key: "quantity")
    var quantity: Int

    @Field(key: "created_at")
    var createdAt: Date

    init() {}

    init(
        id: UUID? = nil,
        batchID: UUID,
        storageLocationID: UUID,
        quantity: Int,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.$batch.id = batchID
        self.$storageLocation.id = storageLocationID
        self.quantity = quantity
        self.createdAt = createdAt
    }
}
