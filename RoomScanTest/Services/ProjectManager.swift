//
//  ProjectManager.swift
//  RoomScanTest
//
//  Created by Mara Ielciu on 10.03.2026.
//
//  Manages multi-room projects - CRUD operations, persistence,
//  and room <=> project relationships.
//

import Foundation
import Combine
import SwiftData

class ProjectManager: ObservableObject {
    @Published var projects: [Project] = []

    private let userManager: UserManager
    private let roomManager: RoomManager
    private let modelContext: ModelContext

    init(userManager: UserManager, roomManager: RoomManager, modelContext: ModelContext) {
        self.userManager = userManager
        self.roomManager = roomManager
        self.modelContext = modelContext
        reloadForCurrentUser()
    }

    func reloadForCurrentUser() {
        loadProjects()
    }

    // MARK: - CRUD

    @discardableResult
    func createProject(name: String, description: String = "") -> Project {
        guard let userId = userManager.currentUser?.id else {
            fatalError("No current user")
        }
        let project = Project(name: name, description: description, userId: userId)
        projects.append(project)
        persist(project)
        return project
    }

    func updateProject(_ project: Project) {
        guard let idx = projects.firstIndex(where: { $0.id == project.id }) else { return }
        var updated = project
        updated.updatedAt = Date()
        projects[idx] = updated
        persist(updated)
    }

    func deleteProject(_ project: Project) {
        for roomId in project.roomIds {
            if let roomIdx = roomManager.rooms.firstIndex(where: { $0.id == roomId }) {
                var room = roomManager.rooms[roomIdx]
                room.projectId = nil
                roomManager.updateRoom(room)
            }
        }
        projects.removeAll { $0.id == project.id }
        deleteEntity(for: project)
    }

    func getProjectsForCurrentUser() -> [Project] {
        guard let userId = userManager.currentUser?.id else { return [] }
        return projects
            .filter { $0.userId == userId }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    // MARK: - Room <=> Project Relationships

    func addRoom(_ room: Room, to project: Project) {
        guard let idx = projects.firstIndex(where: { $0.id == project.id }) else { return }
        if !projects[idx].roomIds.contains(room.id) {
            projects[idx].roomIds.append(room.id)
            projects[idx].updatedAt = Date()
            persist(projects[idx])

            var updatedRoom = room
            updatedRoom.projectId = project.id
            roomManager.updateRoom(updatedRoom)
        }
    }

    func removeRoom(_ room: Room, from project: Project) {
        guard let idx = projects.firstIndex(where: { $0.id == project.id }) else { return }
        projects[idx].roomIds.removeAll { $0 == room.id }
        projects[idx].updatedAt = Date()
        persist(projects[idx])

        var updatedRoom = room
        updatedRoom.projectId = nil
        roomManager.updateRoom(updatedRoom)
    }

    func removeRoomReferences(for roomId: UUID) {
        var changed = false
        for idx in projects.indices {
            let before = projects[idx].roomIds.count
            projects[idx].roomIds.removeAll { $0 == roomId }
            if projects[idx].roomIds.count != before {
                projects[idx].updatedAt = Date()
                persist(projects[idx])
                changed = true
            }
        }
        _ = changed
    }

    func rooms(for project: Project) -> [Room] {
        project.roomIds.compactMap { roomId in
            roomManager.rooms.first { $0.id == roomId }
        }
    }

    func unassignedRooms() -> [Room] {
        let assignedIds = Set(projects.flatMap(\.roomIds))
        return roomManager.getRoomsForCurrentUser().filter { !assignedIds.contains($0.id) }
    }

    // MARK: - Aggregate Statistics

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

    // MARK: - SwiftData persistence

    private func loadProjects() {
        guard let userId = userManager.currentUser?.id else { projects = []; return }
        let descriptor = FetchDescriptor<ProjectEntity>(
            predicate: #Predicate { $0.userId == userId },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        projects = (try? modelContext.fetch(descriptor))?.map { $0.toProject() } ?? []
    }

    private func persist(_ project: Project) {
        let projectId = project.id
        let descriptor = FetchDescriptor<ProjectEntity>(predicate: #Predicate { $0.id == projectId })
        if let entity = try? modelContext.fetch(descriptor).first {
            entity.update(from: project)
        } else {
            modelContext.insert(ProjectEntity(from: project))
        }
        try? modelContext.save()
    }

    private func deleteEntity(for project: Project) {
        let projectId = project.id
        let descriptor = FetchDescriptor<ProjectEntity>(predicate: #Predicate { $0.id == projectId })
        if let entity = try? modelContext.fetch(descriptor).first {
            modelContext.delete(entity)
            try? modelContext.save()
        }
    }
}
