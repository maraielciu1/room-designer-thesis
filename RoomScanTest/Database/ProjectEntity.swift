//
//  ProjectEntity.swift
//  RoomScanTest
//
//  SwiftData record for Project. roomIds:[UUID] is stored as a JSON string.
//  Note: stored column is `projectDescription` to avoid NSObject.description conflict.
//

import Foundation
import SwiftData

@Model
final class ProjectEntity {
    @Attribute(.unique) var id: UUID
    var name: String
    var projectDescription: String
    var userId: UUID
    var roomIdsJSON: String
    var createdAt: Date
    var updatedAt: Date

    init(from project: Project) {
        self.id = project.id
        self.name = project.name
        self.projectDescription = project.description
        self.userId = project.userId
        self.roomIdsJSON = Self.encodeUUIDs(project.roomIds)
        self.createdAt = project.createdAt
        self.updatedAt = project.updatedAt
    }

    func update(from project: Project) {
        name = project.name
        projectDescription = project.description
        userId = project.userId
        roomIdsJSON = Self.encodeUUIDs(project.roomIds)
        updatedAt = project.updatedAt
    }

    func toProject() -> Project {
        Project(
            id: id,
            name: name,
            description: projectDescription,
            userId: userId,
            roomIds: Self.decodeUUIDs(roomIdsJSON),
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    // MARK: - Helpers

    private static func encodeUUIDs(_ ids: [UUID]) -> String {
        let strings = ids.map(\.uuidString)
        return (try? String(data: JSONEncoder().encode(strings), encoding: .utf8)) ?? "[]"
    }

    private static func decodeUUIDs(_ json: String) -> [UUID] {
        guard let data = json.data(using: .utf8),
              let strings = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        return strings.compactMap { UUID(uuidString: $0) }
    }
}
