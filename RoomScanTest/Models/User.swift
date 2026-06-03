//
//  User.swift
//  RoomScanTest
//
//  Created by Mara Ielciu on 16.02.2026.
//

import Foundation

struct User: Identifiable, Codable {
    let id: UUID
    var name: String
    var email: String
    var createdAt: Date
    var authProvider: AuthProvider
    var googleUserId: String?

    init(
        id: UUID = UUID(),
        name: String,
        email: String,
        createdAt: Date = Date(),
        authProvider: AuthProvider = .email,
        googleUserId: String? = nil
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.createdAt = createdAt
        self.authProvider = authProvider
        self.googleUserId = googleUserId
    }

    enum CodingKeys: String, CodingKey {
        case id, name, email, createdAt, authProvider, googleUserId
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        email = try c.decode(String.self, forKey: .email)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        authProvider = try c.decodeIfPresent(AuthProvider.self, forKey: .authProvider) ?? .email
        googleUserId = try c.decodeIfPresent(String.self, forKey: .googleUserId)
    }
}
