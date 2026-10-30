import Vapor

struct BearerTokenMiddleware: AsyncMiddleware {
    private let service = AuthService()

    func respond(
        to request: Request,
        chainingTo next: AsyncResponder
    ) async throws -> Response {
        guard let bearer = request.headers.bearerAuthorization else {
            throw Abort(.unauthorized, reason: "Authentication required")
        }

        let user = try await service.authenticate(
            token: bearer.token,
            on: request.db
        )

        request.auth.login(user)
        return try await next.respond(to: request)
    }
}

struct RoleMiddleware: AsyncMiddleware {
    let allowedRoles: Set<String>

    func respond(
        to request: Request,
        chainingTo next: AsyncResponder
    ) async throws -> Response {
        guard let user = request.auth.get(AppUser.self) else {
            throw Abort(.unauthorized)
        }

        guard allowedRoles.contains(user.role) else {
            throw Abort(.forbidden, reason: "Insufficient permissions")
        }

        return try await next.respond(to: request)
    }
}
