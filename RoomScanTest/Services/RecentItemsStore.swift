//
//  RecentItemsStore.swift
//  RoomScanTest
//
//  UserDefaults-backed store for recently viewed rooms, recently used
//  furniture models, and recently created projects. Each list is capped
//  at three entries and scoped per user so accounts do not share recents.
//

import Foundation
import Combine

struct RecentRoom: Codable, Identifiable, Equatable {
    let id: UUID
    let name: String
}

struct RecentFurniture: Codable, Identifiable, Equatable {
    let id: UUID
    let modelKey: String
    let displayName: String
}

struct RecentProject: Codable, Identifiable, Equatable {
    let id: UUID
    let name: String
}

final class RecentItemsStore: ObservableObject {
    static let shared = RecentItemsStore()

    private let maxCount = 3

    @Published private(set) var recentRooms: [RecentRoom] = []
    @Published private(set) var recentFurniture: [RecentFurniture] = []
    @Published private(set) var recentProjects: [RecentProject] = []

    private var userId: UUID?

    private func key(_ base: String) -> String {
        guard let uid = userId else { return base }
        return "\(base)_\(uid.uuidString)"
    }

    func configure(for userId: UUID) {
        self.userId = userId
        recentRooms    = load([RecentRoom].self,      key: "recent_rooms")      ?? []
        recentFurniture = load([RecentFurniture].self, key: "recent_furniture") ?? []
        recentProjects  = load([RecentProject].self,   key: "recent_projects")  ?? []
    }

    // MARK: - Record

    func recordRoom(_ room: RecentRoom) {
        recentRooms.removeAll { $0.id == room.id }
        recentRooms.insert(room, at: 0)
        if recentRooms.count > maxCount { recentRooms = Array(recentRooms.prefix(maxCount)) }
        save(recentRooms, key: "recent_rooms")
    }

    func recordFurniture(_ item: RecentFurniture) {
        recentFurniture.removeAll { $0.modelKey == item.modelKey }
        recentFurniture.insert(item, at: 0)
        if recentFurniture.count > maxCount { recentFurniture = Array(recentFurniture.prefix(maxCount)) }
        save(recentFurniture, key: "recent_furniture")
    }

    func recordProject(_ project: RecentProject) {
        recentProjects.removeAll { $0.id == project.id }
        recentProjects.insert(project, at: 0)
        if recentProjects.count > maxCount { recentProjects = Array(recentProjects.prefix(maxCount)) }
        save(recentProjects, key: "recent_projects")
    }

    // MARK: - Helpers

    private func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: self.key(key)) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private func save<T: Encodable>(_ value: T, key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        UserDefaults.standard.set(data, forKey: self.key(key))
    }
}
