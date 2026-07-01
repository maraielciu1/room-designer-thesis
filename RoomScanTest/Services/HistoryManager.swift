//
//  HistoryManager.swift
//  RoomScanTest
//
//  Created by Mara Ielciu on 16.02.2026.
//

import Foundation
import Combine
import SwiftData

class HistoryManager: ObservableObject {
    @Published var history: [ReplacementHistory] = []

    private let userManager: UserManager
    private let modelContext: ModelContext

    init(userManager: UserManager, modelContext: ModelContext) {
        self.userManager = userManager
        self.modelContext = modelContext
        reloadForCurrentUser()
    }

    func reloadForCurrentUser() {
        loadHistory()
    }

    func addHistoryEntry(roomId: UUID, replacementId: UUID, action: ReplacementHistory.HistoryAction, details: String = "") {
        guard let userId = userManager.currentUser?.id else { return }
        let entry = ReplacementHistory(
            userId: userId,
            roomId: roomId,
            replacementId: replacementId,
            action: action,
            details: details
        )
        history.append(entry)
        persist(entry)
    }

    func getHistoryForUser() -> [ReplacementHistory] {
        guard let userId = userManager.currentUser?.id else { return [] }
        return history.filter { $0.userId == userId }
            .sorted { $0.timestamp > $1.timestamp }
    }

    func getHistoryForRoom(_ roomId: UUID) -> [ReplacementHistory] {
        return history.filter { $0.roomId == roomId }
            .sorted { $0.timestamp > $1.timestamp }
    }

    func clearHistory() {
        guard let userId = userManager.currentUser?.id else { return }
        let toDelete = history.filter { $0.userId == userId }
        history.removeAll { $0.userId == userId }
        for entry in toDelete { deleteEntity(for: entry) }
    }

    // MARK: - SwiftData persistence

    private func loadHistory() {
        guard let userId = userManager.currentUser?.id else { history = []; return }
        let descriptor = FetchDescriptor<ReplacementHistoryEntity>(
            predicate: #Predicate { $0.userId == userId },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        history = (try? modelContext.fetch(descriptor))?.map { $0.toHistory() } ?? []
    }

    private func persist(_ entry: ReplacementHistory) {
        let entryId = entry.id
        let descriptor = FetchDescriptor<ReplacementHistoryEntity>(predicate: #Predicate { $0.id == entryId })
        if (try? modelContext.fetch(descriptor).first) != nil {
            // History entries are immutable — no update needed
        } else {
            modelContext.insert(ReplacementHistoryEntity(from: entry))
        }
        try? modelContext.save()
    }

    private func deleteEntity(for entry: ReplacementHistory) {
        let entryId = entry.id
        let descriptor = FetchDescriptor<ReplacementHistoryEntity>(predicate: #Predicate { $0.id == entryId })
        if let entity = try? modelContext.fetch(descriptor).first {
            modelContext.delete(entity)
            try? modelContext.save()
        }
    }
}
