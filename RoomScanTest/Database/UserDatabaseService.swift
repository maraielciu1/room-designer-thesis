//
//  UserDatabaseService.swift
//  RoomScanTest
//

import Foundation
import SwiftData

@MainActor
final class UserDatabaseService {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetchUser(id: UUID) throws -> AppUserEntity? {
        let descriptor = FetchDescriptor<AppUserEntity>(
            predicate: #Predicate { $0.id == id }
        )
        return try modelContext.fetch(descriptor).first
    }

    func fetchUser(email: String) throws -> AppUserEntity? {
        let normalized = email.lowercased()
        let descriptor = FetchDescriptor<AppUserEntity>(
            predicate: #Predicate { $0.email == normalized }
        )
        return try modelContext.fetch(descriptor).first
    }

    func fetchUser(googleUserId: String) throws -> AppUserEntity? {
        let descriptor = FetchDescriptor<AppUserEntity>(
            predicate: #Predicate { $0.googleUserId == googleUserId }
        )
        return try modelContext.fetch(descriptor).first
    }

    func fetchAllUsers() throws -> [AppUserEntity] {
        try modelContext.fetch(FetchDescriptor<AppUserEntity>())
    }

    @discardableResult
    func createEmailUser(name: String, email: String, password: String) throws -> AppUserEntity {
        let normalized = email.lowercased()
        if try fetchUser(email: normalized) != nil {
            throw AuthError.emailAlreadyRegistered
        }
        let salt = PasswordHasher.makeSalt()
        let hash = PasswordHasher.hash(password: password, salt: salt)
        let entity = AppUserEntity(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            email: normalized,
            authProvider: .email,
            passwordSaltBase64: salt.base64EncodedString(),
            passwordHash: hash
        )
        modelContext.insert(entity)
        try modelContext.save()
        return entity
    }

    func verifyPassword(_ password: String, for entity: AppUserEntity) throws -> Bool {
        guard entity.authProvider == .email,
              let saltBase64 = entity.passwordSaltBase64,
              let salt = Data(base64Encoded: saltBase64),
              let expected = entity.passwordHash else {
            throw AuthError.invalidCredentials
        }
        return PasswordHasher.hash(password: password, salt: salt) == expected
    }

    @discardableResult
    func findOrCreateGoogleUser(
        googleUserId: String,
        name: String,
        email: String
    ) throws -> AppUserEntity {
        if let existing = try fetchUser(googleUserId: googleUserId) {
            if existing.name != name, !name.isEmpty {
                existing.name = name
                try modelContext.save()
            }
            return existing
        }

        let normalized = email.lowercased()
        if let linked = try fetchUser(email: normalized) {
            linked.googleUserId = googleUserId
            linked.authProvider = .google
            if !name.isEmpty { linked.name = name }
            try modelContext.save()
            return linked
        }

        let entity = AppUserEntity(
            name: name.isEmpty ? "Google User" : name,
            email: normalized.isEmpty ? "\(googleUserId)@google.user" : normalized,
            authProvider: .google,
            googleUserId: googleUserId
        )
        modelContext.insert(entity)
        try modelContext.save()
        return entity
    }
}

enum AuthError: LocalizedError {
    case emailAlreadyRegistered
    case invalidCredentials
    case weakPassword
    case invalidEmail
    case googleSignInUnavailable
    case googleSignInFailed(String)

    var errorDescription: String? {
        switch self {
        case .emailAlreadyRegistered: return "An account with this email already exists."
        case .invalidCredentials: return "Invalid email or password."
        case .weakPassword: return "Password must be at least 8 characters."
        case .invalidEmail: return "Please enter a valid email address."
        case .googleSignInUnavailable: return "Google Sign-In is not configured."
        case .googleSignInFailed(let msg): return msg
        }
    }
}
