//
//  UserManager.swift
//  RoomScanTest
//
//  Created by Mara Ielciu on 16.02.2026.
//

import Foundation
import Combine

/// Holds the signed-in user for scoping rooms, projects, and scans.
class UserManager: ObservableObject {
    @Published private(set) var currentUser: User?

    func setCurrentUser(_ user: User) {
        currentUser = user
        RecentItemsStore.shared.configure(for: user.id)
    }

    func clearSession() {
        currentUser = nil
    }
}
