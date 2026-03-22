//
//  Project.swift
//  RoomScanTest
//
//  Created by Mara Ielciu on 10.03.2026.
//
//  A Project groups multiple Room scans into a single home / workspace.
//  Each room holds a reference to its parent project via `projectId`.
//

import Foundation

struct Project: Identifiable, Codable {
    let id: UUID
    var name: String
    var description: String
    var userId: UUID
    var roomIds: [UUID]          // Ordered list of room IDs belonging to this project
    var createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(),
         name: String,
         description: String = "",
         userId: UUID,
         roomIds: [UUID] = [],
         createdAt: Date = Date(),
         updatedAt: Date = Date())
    {
        self.id = id
        self.name = name
        self.description = description
        self.userId = userId
        self.roomIds = roomIds
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // MARK: - Convenience

    /// Total number of rooms in this project.
    var roomCount: Int { roomIds.count }
}
