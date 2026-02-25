//
//  UserManager.swift
//  RoomScanTest
//
//  Created by Mara Ielciu on 16.02.2026.
//

import Foundation
import Combine

class UserManager: ObservableObject {
    @Published var currentUser: User?
    @Published var users: [User] = []
    
    private let usersKey = "saved_users"
    private let currentUserIdKey = "current_user_id"
    
    init() {
        loadUsers()
        loadCurrentUser()
    }
    
    func createUser(name: String, email: String) -> User {
        let user = User(name: name, email: email)
        users.append(user)
        saveUsers()
        return user
    }
    
    func setCurrentUser(_ user: User) {
        currentUser = user
        UserDefaults.standard.set(user.id.uuidString, forKey: currentUserIdKey)
    }
    
    func switchUser(_ user: User) {
        setCurrentUser(user)
    }
    
    func deleteUser(_ user: User) {
        users.removeAll { $0.id == user.id }
        if currentUser?.id == user.id {
            currentUser = users.first
            if let newCurrent = currentUser {
                setCurrentUser(newCurrent)
            } else {
                UserDefaults.standard.removeObject(forKey: currentUserIdKey)
            }
        }
        saveUsers()
    }
    
    private func loadUsers() {
        if let data = UserDefaults.standard.data(forKey: usersKey),
           let decoded = try? JSONDecoder().decode([User].self, from: data) {
            users = decoded
        } else {
            // Create default user if none exist
            let defaultUser = createUser(name: "Default User", email: "user@example.com")
            setCurrentUser(defaultUser)
        }
    }
    
    private func saveUsers() {
        if let encoded = try? JSONEncoder().encode(users) {
            UserDefaults.standard.set(encoded, forKey: usersKey)
        }
    }
    
    private func loadCurrentUser() {
        if let userIdString = UserDefaults.standard.string(forKey: currentUserIdKey),
           let userId = UUID(uuidString: userIdString),
           let user = users.first(where: { $0.id == userId }) {
            currentUser = user
        } else if let firstUser = users.first {
            currentUser = firstUser
        }
    }
}
