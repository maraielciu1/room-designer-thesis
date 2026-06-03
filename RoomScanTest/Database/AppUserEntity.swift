//
//  AppUserEntity.swift
//  RoomScanTest
//
//  SwiftData record for registered / signed-in accounts.
//

import Foundation
import SwiftData

@Model
final class AppUserEntity {
    @Attribute(.unique) var id: UUID
    var name: String
    @Attribute(.unique) var email: String
    var createdAt: Date
    var authProviderRaw: String
    var googleUserId: String?
    var passwordSaltBase64: String?
    var passwordHash: String?

    init(
        id: UUID = UUID(),
        name: String,
        email: String,
        createdAt: Date = Date(),
        authProvider: AuthProvider,
        googleUserId: String? = nil,
        passwordSaltBase64: String? = nil,
        passwordHash: String? = nil
    ) {
        self.id = id
        self.name = name
        self.email = email.lowercased()
        self.createdAt = createdAt
        self.authProviderRaw = authProvider.rawValue
        self.googleUserId = googleUserId
        self.passwordSaltBase64 = passwordSaltBase64
        self.passwordHash = passwordHash
    }

    var authProvider: AuthProvider {
        get { AuthProvider(rawValue: authProviderRaw) ?? .email }
        set { authProviderRaw = newValue.rawValue }
    }

    func toUser() -> User {
        User(
            id: id,
            name: name,
            email: email,
            createdAt: createdAt,
            authProvider: authProvider,
            googleUserId: googleUserId
        )
    }
}
