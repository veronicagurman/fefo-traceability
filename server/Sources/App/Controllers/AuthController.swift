import Vapor

struct RegisterRequest: Content {
    let email: String
    let password: String
}

struct LoginRequest: Content {
    let email: String
    let password: String
}

struct UserSummary: Content {
    let id: UUID
    let email: String
    let role: String
    let createdAt: Date

    init(user: AppUser) throws {
        guard let id = user.id else {
            throw Abort(.internalServerError, reason: "User ID is missing")
        }

        self.id = id
        self.email = user.email
        self.role = user.role
        self.createdAt = user.createdAt
    }
}

struct AuthResponse: Content {
    let token: String
    let expiresAt: Date
    let user: UserSummary
}

struct AuthController {
    private let service = AuthService()

    func register(req: Request) async throws -> Response {
        let input = try req.content.decode(RegisterRequest.self)

        let response = try await service.register(
            email: input.email,
            password: input.password,
            on: req.db
        )

        return try await response.encodeResponse(status: .created, for: req)
    }

    func login(req: Request) async throws -> AuthResponse {
        let input = try req.content.decode(LoginRequest.self)

        return try await service.login(
            email: input.email,
            password: input.password,
            on: req.db
        )
    }

    func me(req: Request) throws -> UserSummary {
        guard let user = req.auth.get(AppUser.self) else {
            throw Abort(.unauthorized)
        }

        return try UserSummary(user: user)
    }

    func logout(req: Request) async throws -> HTTPStatus {
        guard let bearer = req.headers.bearerAuthorization else {
            throw Abort(.unauthorized)
        }

        try await service.logout(token: bearer.token, on: req.db)
        return .noContent
    }
}
