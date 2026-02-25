//
//  ReplacementHistory.swift
//  RoomScanTest
//
//  Created by Mara Ielciu on 16.02.2026.
//

import Foundation

struct ReplacementHistory: Identifiable, Codable {
    let id: UUID
    var userId: UUID
    var roomId: UUID
    var replacementId: UUID
    var action: HistoryAction
    var timestamp: Date
    var details: String
    
    enum HistoryAction: String, Codable {
        case replaced = "replaced"
        case removed = "removed"
        case updated = "updated"
    }
    
    init(id: UUID = UUID(), userId: UUID, roomId: UUID, replacementId: UUID, action: HistoryAction, timestamp: Date = Date(), details: String = "") {
        self.id = id
        self.userId = userId
        self.roomId = roomId
        self.replacementId = replacementId
        self.action = action
        self.timestamp = timestamp
        self.details = details
    }
}
