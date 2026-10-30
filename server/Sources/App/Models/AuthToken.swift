import Fluent
import Vapor

final class AuthToken: Model, Content, @unchecked Sendable {
    static let schema = "auth_tokens"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "user_id")
    var user: AppUser

    @Field(key: "token_hash")
    var tokenHash: String

    @Field(key: "expires_at")
    var expiresAt: Date

    init() {}

    init(
        id: UUID? = nil,
        userID: UUID,
        tokenHash: String,
        expiresAt: Date
    ) {
        self.id = id
        self.$user.id = userID
        self.tokenHash = tokenHash
        self.expiresAt = expiresAt
    }
}
