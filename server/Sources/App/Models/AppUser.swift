import Fluent
import Vapor

enum AppUserRole: String, CaseIterable {
    case admin
    case warehouseWorker = "warehouse_worker"
    case salesManager = "sales_manager"
    case warehouseManager = "warehouse_manager"
}

final class AppUser: Model, Content, Authenticatable, @unchecked Sendable {
    static let schema = "app_users"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "email")
    var email: String

    @Field(key: "password_hash")
    var passwordHash: String

    @Field(key: "role")
    var role: String

    @Field(key: "created_at")
    var createdAt: Date

    init() {}

    init(
        id: UUID? = nil,
        email: String,
        passwordHash: String,
        role: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.email = email
        self.passwordHash = passwordHash
        self.role = role
        self.createdAt = createdAt
    }
}
