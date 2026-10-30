import CryptoKit
import Fluent
import Foundation
import Vapor

struct AuthService {
    func register(email rawEmail: String, password: String, on db: Database) async throws -> AuthResponse {
        let email = rawEmail
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard email.count <= 254,
              email.split(separator: "@").count == 2,
              email.contains(".") else {
            throw Abort(.badRequest, reason: "Invalid email address")
        }

        guard password.count >= 12 else {
            throw Abort(.badRequest, reason: "Password must contain at least 12 characters")
        }

        let existingUser = try await AppUser.query(on: db)
            .filter(\.$email == email)
            .first()

        guard existingUser == nil else {
            throw Abort(.conflict, reason: "Email is already registered")
        }

        let user = AppUser(
            email: email,
            passwordHash: try Bcrypt.hash(password),
            role: AppUserRole.warehouseWorker.rawValue
        )

        try await user.save(on: db)
        return try await createSession(for: user, on: db)
    }

    func login(email rawEmail: String, password: String, on db: Database) async throws -> AuthResponse {
        let email = rawEmail
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard let user = try await AppUser.query(on: db)
            .filter(\.$email == email)
            .first(),
              try Bcrypt.verify(password, created: user.passwordHash) else {
            throw Abort(.unauthorized, reason: "Invalid email or password")
        }

        return try await createSession(for: user, on: db)
    }

    func logout(token: String, on db: Database) async throws {
        let tokenHash = Self.hashToken(token)

        if let storedToken = try await AuthToken.query(on: db)
            .filter(\.$tokenHash == tokenHash)
            .first() {
            try await storedToken.delete(on: db)
        }
    }

    func authenticate(token: String, on db: Database) async throws -> AppUser {
        let tokenHash = Self.hashToken(token)

        guard let storedToken = try await AuthToken.query(on: db)
            .filter(\.$tokenHash == tokenHash)
            .first(),
              storedToken.expiresAt > Date() else {
            throw Abort(.unauthorized, reason: "Invalid or expired token")
        }

        guard let user = try await AppUser.find(storedToken.$user.id, on: db) else {
            throw Abort(.unauthorized, reason: "User not found")
        }

        return user
    }

    private func createSession(for user: AppUser, on db: Database) async throws -> AuthResponse {
        guard let userID = user.id else {
            throw Abort(.internalServerError, reason: "User ID is missing")
        }

        let rawToken = UUID().uuidString + UUID().uuidString
        let expiresAt = Date().addingTimeInterval(24 * 60 * 60)

        let storedToken = AuthToken(
            userID: userID,
            tokenHash: Self.hashToken(rawToken),
            expiresAt: expiresAt
        )

        try await storedToken.save(on: db)

        return AuthResponse(
            token: rawToken,
            expiresAt: expiresAt,
            user: try UserSummary(user: user)
        )
    }

    static func hashToken(_ token: String) -> String {
        SHA256.hash(data: Data(token.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
