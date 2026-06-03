//
//  ProjectManager.swift
//  RoomScanTest
//
//  Created by Mara Ielciu on 10.03.2026.
//
//  Manages multi-room projects — CRUD operations, persistence,
//  and room ↔ project relationships.
//

import Foundation
import Combine

class ProjectManager: ObservableObject {
    @Published var projects: [Project] = []

    private let storageKey = "saved_projects"
    private let userManager: UserManager
    private let roomManager: RoomManager

    init(userManager: UserManager, roomManager: RoomManager) {
        self.userManager = userManager
        self.roomManager = roomManager
        reloadForCurrentUser()
    }

    func reloadForCurrentUser() {
        loadProjects()
    }

    // MARK: - CRUD

    /// Create a new project for the current user.
    @discardableResult
    func createProject(name: String, description: String = "") -> Project {
        guard let userId = userManager.currentUser?.id else {
            fatalError("No current user")
        }
        let project = Project(name: name, description: description, userId: userId)
        projects.append(project)
        save()
        return project
    }

    /// Update an existing project.
    func updateProject(_ project: Project) {
        guard let idx = projects.firstIndex(where: { $0.id == project.id }) else { return }
        var updated = project
        updated.updatedAt = Date()
        projects[idx] = updated
        save()
    }

    /// Delete a project. Does NOT delete its rooms — they become unassigned.
    func deleteProject(_ project: Project) {
        // Remove projectId from all rooms that belong to this project
        for roomId in project.roomIds {
            if let roomIdx = roomManager.rooms.firstIndex(where: { $0.id == roomId }) {
                var room = roomManager.rooms[roomIdx]
                room.projectId = nil
                roomManager.updateRoom(room)
            }
        }
        projects.removeAll { $0.id == project.id }
        save()
    }

    /// Projects for the current user, sorted by most recently updated.
    func getProjectsForCurrentUser() -> [Project] {
        guard let userId = userManager.currentUser?.id else { return [] }
        return projects
            .filter { $0.userId == userId }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    // MARK: - Room ↔ Project Relationships

    /// Add a room to a project.
    func addRoom(_ room: Room, to project: Project) {
        guard let idx = projects.firstIndex(where: { $0.id == project.id }) else { return }
        if !projects[idx].roomIds.contains(room.id) {
            projects[idx].roomIds.append(room.id)
            projects[idx].updatedAt = Date()
            save()

            // Also tag the room
            var updatedRoom = room
            updatedRoom.projectId = project.id
            roomManager.updateRoom(updatedRoom)
        }
    }

    /// Remove a room from a project.
    func removeRoom(_ room: Room, from project: Project) {
        guard let idx = projects.firstIndex(where: { $0.id == project.id }) else { return }
        projects[idx].roomIds.removeAll { $0 == room.id }
        projects[idx].updatedAt = Date()
        save()

        // Clear room's project reference
        var updatedRoom = room
        updatedRoom.projectId = nil
        roomManager.updateRoom(updatedRoom)
    }

    /// Drop a deleted room from every project that references it.
    func removeRoomReferences(for roomId: UUID) {
        var changed = false
        for idx in projects.indices {
            let before = projects[idx].roomIds.count
            projects[idx].roomIds.removeAll { $0 == roomId }
            if projects[idx].roomIds.count != before {
                projects[idx].updatedAt = Date()
                changed = true
            }
        }
        if changed { save() }
    }

    /// Resolve Room objects for a project.
    func rooms(for project: Project) -> [Room] {
        project.roomIds.compactMap { roomId in
            roomManager.rooms.first { $0.id == roomId }
        }
    }

    /// Rooms that are NOT assigned to any project (for the current user).
    func unassignedRooms() -> [Room] {
        let assignedIds = Set(projects.flatMap(\.roomIds))
        return roomManager.getRoomsForCurrentUser().filter { !assignedIds.contains($0.id) }
    }

    // MARK: - Aggregate Statistics

    /// Combined measurements across all rooms in a project.
    func projectSummary(for project: Project) -> (roomCount: Int, totalArea: Float, totalVolume: Float, itemCount: Int) {
        let projectRooms = rooms(for: project)
        var totalArea: Float = 0
        var totalVolume: Float = 0
        var itemCount = 0

        for room in projectRooms {
            if let captured = room.getCapturedRoom() {
                let m = MeasurementService.measure(captured)
                totalArea += m.floorArea
                totalVolume += m.volume
            }
            itemCount += room.furnitureReplacements.count
        }

        return (projectRooms.count, totalArea, totalVolume, itemCount)
    }

    // MARK: - Persistence

    private func loadProjects() {
        guard let userId = userManager.currentUser?.id else {
            projects = []
            return
        }
        projects = UserScopedStorage.load([Project].self, baseKey: storageKey, userId: userId) ?? []
    }

    private func save() {
        guard let userId = userManager.currentUser?.id else { return }
        UserScopedStorage.save(projects, baseKey: storageKey, userId: userId)
    }
}
