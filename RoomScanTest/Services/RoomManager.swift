//
//  RoomManager.swift
//  RoomScanTest
//
//  Created by Mara Ielciu on 16.02.2026.
//

import Foundation
import Combine
import RoomPlan
import SwiftData

class RoomManager: ObservableObject {
    @Published var rooms: [Room] = []

    private let userManager: UserManager
    private let modelContext: ModelContext

    init(userManager: UserManager, modelContext: ModelContext) {
        self.userManager = userManager
        self.modelContext = modelContext
        reloadForCurrentUser()
    }

    func reloadForCurrentUser() {
        loadRooms()
        // Only clean orphaned scan files when we actually loaded rooms.
        // An empty result on first launch (before migration) must not be
        // treated as "all files are orphaned" — that would delete valid scans.
        if let userId = userManager.currentUser?.id, !rooms.isEmpty {
            Room.cleanOrphanedScanFiles(userId: userId, existingRoomIds: Set(rooms.map(\.id)))
        }
    }

    func createRoom(name: String, capturedRoom: CapturedRoom? = nil, roomMaterials: RoomMaterials? = nil) -> Room {
        guard let userId = userManager.currentUser?.id else {
            fatalError("No current user")
        }

        var room = Room(name: name, userId: userId, roomMaterials: roomMaterials)
        if let capturedRoom = capturedRoom {
            room.setCapturedRoom(capturedRoom)
        }

        let recentDuplicate = rooms.first { existingRoom in
            existingRoom.userId == userId &&
            existingRoom.name == name &&
            abs(existingRoom.createdAt.timeIntervalSinceNow) < 1.0
        }

        if recentDuplicate == nil {
            rooms.append(room)
            persist(room)
        } else {
            return recentDuplicate!
        }

        return room
    }

    func removeDuplicateRooms() {
        var seenRooms: [String: Room] = [:]
        var roomsToKeep: [Room] = []

        for room in rooms {
            let similarKey = "\(room.userId.uuidString)_\(room.name)"
            if let existing = seenRooms[similarKey],
               abs(existing.createdAt.timeIntervalSince(room.createdAt)) < 1.0 {
                room.deleteScanData()
                deleteEntity(for: room)
                continue
            }
            seenRooms[similarKey] = room
            roomsToKeep.append(room)
        }

        if roomsToKeep.count < rooms.count {
            rooms = roomsToKeep
        }
    }

    func updateRoom(_ room: Room) {
        if let index = rooms.firstIndex(where: { $0.id == room.id }) {
            var updatedRoom = room
            updatedRoom.updatedAt = Date()
            rooms[index] = updatedRoom
            persist(updatedRoom)
        }
    }

    func deleteRoom(_ room: Room) {
        room.deleteScanData()
        rooms.removeAll { $0.id == room.id }
        deleteEntity(for: room)
    }

    func getRoomsForCurrentUser() -> [Room] {
        guard let userId = userManager.currentUser?.id else { return [] }
        return rooms.filter { $0.userId == userId }
    }

    func addReplacement(to room: Room, replacement: FurnitureReplacement) {
        if let index = rooms.firstIndex(where: { $0.id == room.id }) {
            rooms[index].furnitureReplacements.append(replacement)
            rooms[index].updatedAt = Date()
            persist(rooms[index])
        }
    }

    func updateReplacement(in room: Room, replacement: FurnitureReplacement) {
        if let index = rooms.firstIndex(where: { $0.id == room.id }),
           let replacementIndex = rooms[index].furnitureReplacements.firstIndex(where: { $0.id == replacement.id }) {
            rooms[index].furnitureReplacements[replacementIndex] = replacement
            rooms[index].updatedAt = Date()
            persist(rooms[index])
        }
    }

    func removeReplacement(from room: Room, replacementId: UUID) {
        if let index = rooms.firstIndex(where: { $0.id == room.id }) {
            rooms[index].furnitureReplacements.removeAll { $0.id == replacementId }
            rooms[index].updatedAt = Date()
            persist(rooms[index])
        }
    }

    // MARK: - SwiftData persistence

    private func loadRooms() {
        guard let userId = userManager.currentUser?.id else { rooms = []; return }
        var descriptor = FetchDescriptor<RoomEntity>(
            predicate: #Predicate { $0.userId == userId },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        descriptor.relationshipKeyPathsForPrefetching = [\.furnitureReplacements]
        rooms = (try? modelContext.fetch(descriptor))?.map { $0.toRoom() } ?? []
    }

    private func persist(_ room: Room) {
        let roomId = room.id
        let descriptor = FetchDescriptor<RoomEntity>(predicate: #Predicate { $0.id == roomId })
        if let entity = try? modelContext.fetch(descriptor).first {
            entity.update(from: room, context: modelContext)
        } else {
            let entity = RoomEntity(from: room)
            modelContext.insert(entity)
            for replacement in room.furnitureReplacements {
                let repEntity = FurnitureReplacementEntity(from: replacement)
                repEntity.room = entity
                entity.furnitureReplacements.append(repEntity)
            }
        }
        try? modelContext.save()
    }

    private func deleteEntity(for room: Room) {
        let roomId = room.id
        let descriptor = FetchDescriptor<RoomEntity>(predicate: #Predicate { $0.id == roomId })
        if let entity = try? modelContext.fetch(descriptor).first {
            modelContext.delete(entity)
            try? modelContext.save()
        }
    }
}
