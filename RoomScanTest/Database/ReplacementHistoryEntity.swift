//
//  ReplacementHistoryEntity.swift
//  RoomScanTest
//
//  SwiftData record for ReplacementHistory.
//

import Foundation
import SwiftData

@Model
final class ReplacementHistoryEntity {
    @Attribute(.unique) var id: UUID
    var userId: UUID
    var roomId: UUID
    var replacementId: UUID
    var actionRaw: String
    var timestamp: Date
    var details: String

    init(from entry: ReplacementHistory) {
        self.id = entry.id
        self.userId = entry.userId
        self.roomId = entry.roomId
        self.replacementId = entry.replacementId
        self.actionRaw = entry.action.rawValue
        self.timestamp = entry.timestamp
        self.details = entry.details
    }

    func toHistory() -> ReplacementHistory {
        ReplacementHistory(
            id: id,
            userId: userId,
            roomId: roomId,
            replacementId: replacementId,
            action: ReplacementHistory.HistoryAction(rawValue: actionRaw) ?? .updated,
            timestamp: timestamp,
            details: details
        )
    }
}
