//
//  RoomManager.swift
//  RoomScanTest
//
//  Created by Mara Ielciu on 16.02.2026.
//

import Foundation
import Combine
import RoomPlan

class RoomManager: ObservableObject {
    @Published var rooms: [Room] = []
    
    private let roomsKey = "saved_rooms"
    private let userManager: UserManager
    
    init(userManager: UserManager) {
        self.userManager = userManager
        reloadForCurrentUser()
    }

    func reloadForCurrentUser() {
        loadRooms()
        if let userId = userManager.currentUser?.id {
            Room.cleanOrphanedScanFiles(userId: userId, existingRoomIds: Set(rooms.map(\.id)))
        }
    }
    
    func createRoom(name: String, capturedRoom: CapturedRoom? = nil, roomMaterials: RoomMaterials? = nil) -> Room {
        guard let userId = userManager.currentUser?.id else {
            fatalError("No current user")
        }
        
        var room = Room(name: name, userId: userId, roomMaterials: roomMaterials)
        if let capturedRoom = capturedRoom {
            room.setCapturedRoom(capturedRoom) // saves to memory + disk
        }
        
        // Check for duplicates before adding (same name and user, created within last second)
        let recentDuplicate = rooms.first { existingRoom in
            existingRoom.userId == userId &&
            existingRoom.name == name &&
            abs(existingRoom.createdAt.timeIntervalSinceNow) < 1.0
        }
        
        // Only add if no recent duplicate exists
        if recentDuplicate == nil {
            rooms.append(room)
            saveRooms()
        } else {
            // Return the existing room instead of creating duplicate
            return recentDuplicate!
        }
        
        return room
    }
    
    func removeDuplicateRooms() {
        // Remove duplicate rooms (same name, same user, created within 1 second of each other)
        var seenRooms: [String: Room] = [:]
        var roomsToKeep: [Room] = []
        
        for room in rooms {
            let similarKey = "\(room.userId.uuidString)_\(room.name)"
            if let existing = seenRooms[similarKey],
               abs(existing.createdAt.timeIntervalSince(room.createdAt)) < 1.0 {
                // This is a duplicate — clean up its scan file
                room.deleteScanData()
                continue
            }
            
            seenRooms[similarKey] = room
            roomsToKeep.append(room)
        }
        
        if roomsToKeep.count < rooms.count {
            rooms = roomsToKeep
            saveRooms()
        }
    }
    
    func updateRoom(_ room: Room) {
        if let index = rooms.firstIndex(where: { $0.id == room.id }) {
            var updatedRoom = room
            updatedRoom.updatedAt = Date()
            rooms[index] = updatedRoom
            saveRooms()
        }
    }
    
    func deleteRoom(_ room: Room) {
        // Delete the scan data file from disk first
        room.deleteScanData()
        rooms.removeAll { $0.id == room.id }
        saveRooms()
    }
    
    func getRoomsForCurrentUser() -> [Room] {
        guard let userId = userManager.currentUser?.id else { return [] }
        return rooms.filter { $0.userId == userId }
    }
    
    func addReplacement(to room: Room, replacement: FurnitureReplacement) {
        if let index = rooms.firstIndex(where: { $0.id == room.id }) {
            rooms[index].furnitureReplacements.append(replacement)
            rooms[index].updatedAt = Date()
            saveRooms()
        }
    }
    
    func updateReplacement(in room: Room, replacement: FurnitureReplacement) {
        if let index = rooms.firstIndex(where: { $0.id == room.id }),
           let replacementIndex = rooms[index].furnitureReplacements.firstIndex(where: { $0.id == replacement.id }) {
            rooms[index].furnitureReplacements[replacementIndex] = replacement
            rooms[index].updatedAt = Date()
            saveRooms()
        }
    }
    
    func removeReplacement(from room: Room, replacementId: UUID) {
        if let index = rooms.firstIndex(where: { $0.id == room.id }) {
            rooms[index].furnitureReplacements.removeAll { $0.id == replacementId }
            rooms[index].updatedAt = Date()
            saveRooms()
        }
    }
    
    private func loadRooms() {
        guard let userId = userManager.currentUser?.id else {
            rooms = []
            return
        }
        rooms = UserScopedStorage.load([Room].self, baseKey: roomsKey, userId: userId) ?? []
    }

    private func saveRooms() {
        guard let userId = userManager.currentUser?.id else { return }
        UserScopedStorage.save(rooms, baseKey: roomsKey, userId: userId)
    }
}
