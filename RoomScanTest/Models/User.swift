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
    
    init(id: UUID = UUID(), name: String, email: String, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.email = email
        self.createdAt = createdAt
    }
}
