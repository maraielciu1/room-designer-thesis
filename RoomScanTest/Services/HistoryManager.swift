//
//  HistoryManager.swift
//  RoomScanTest
//
//  Created by Mara Ielciu on 16.02.2026.
//

import Foundation
import Combine

class HistoryManager: ObservableObject {
    @Published var history: [ReplacementHistory] = []
    
    private let historyKey = "replacement_history"
    private let userManager: UserManager
    
    init(userManager: UserManager) {
        self.userManager = userManager
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
        saveHistory()
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
        history.removeAll { $0.userId == userId }
        saveHistory()
    }
    
    private func loadHistory() {
        if let data = UserDefaults.standard.data(forKey: historyKey),
           let decoded = try? JSONDecoder().decode([ReplacementHistory].self, from: data) {
            history = decoded
        }
    }
    
    private func saveHistory() {
        if let encoded = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(encoded, forKey: historyKey)
        }
    }
}
