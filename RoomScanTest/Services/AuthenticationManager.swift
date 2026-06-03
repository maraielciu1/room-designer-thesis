//
//  AuthenticationManager.swift
//  RoomScanTest
//

import Foundation
import SwiftData
import Combine
import UIKit

@MainActor
final class AuthenticationManager: ObservableObject {
    @Published private(set) var isAuthenticated = false
    @Published var errorMessage: String?

    func showError(_ message: String) {
        errorMessage = message
    }
    @Published var isLoading = false

    private let userManager: UserManager
    private let database: UserDatabaseService

    var onAuthStateChanged: (() -> Void)?

    init(modelContainer: ModelContainer, userManager: UserManager) {
        self.userManager = userManager
        self.database = UserDatabaseService(modelContext: modelContainer.mainContext)
        GoogleSignInService.configureIfNeeded()
        LegacyDataMigration.migrateAllPreAuthDataToMara(database: database)
    }

    func restoreSession() {
        guard let userId = KeychainSessionStore.loadUserId(),
              let entity = try? database.fetchUser(id: userId) else {
            isAuthenticated = false
            return
        }
        completeSignIn(entity: entity)
    }

    func register(name: String, email: String, password: String) async {
        await runAuthOperation {
            try validateEmail(email)
            try validatePassword(password)
            let entity = try database.createEmailUser(name: name, email: email, password: password)
            completeSignIn(entity: entity)
        }
    }

    func signIn(email: String, password: String) async {
        await runAuthOperation {
            try validateEmail(email)
            guard let entity = try database.fetchUser(email: email) else {
                throw AuthError.invalidCredentials
            }
            guard try database.verifyPassword(password, for: entity) else {
                throw AuthError.invalidCredentials
            }
            completeSignIn(entity: entity)
        }
    }

    func signInWithGoogle() async {
        guard let root = Self.topViewController() else {
            errorMessage = "Could not present Google Sign-In."
            return
        }
        await runAuthOperation {
            let profile = try await GoogleSignInService.signIn(presenting: root)
            let entity = try database.findOrCreateGoogleUser(
                googleUserId: profile.userId,
                name: profile.name,
                email: profile.email
            )
            completeSignIn(entity: entity)
        }
    }

    func signOut() {
        GoogleSignInService.signOut()
        KeychainSessionStore.deleteUserId()
        userManager.clearSession()
        isAuthenticated = false
        onAuthStateChanged?()
    }

    // MARK: - Private

    private func completeSignIn(entity: AppUserEntity) {
        let user = entity.toUser()
        LegacyDataMigration.migrateAllPreAuthDataToMara(database: database)
        UserScopedStorage.migrateLegacyDataIfNeeded(to: user.id)
        userManager.setCurrentUser(user)
        KeychainSessionStore.saveUserId(user.id)
        isAuthenticated = true
        errorMessage = nil
        onAuthStateChanged?()
    }

    private func runAuthOperation(_ operation: () async throws -> Void) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await operation()
        } catch let error as AuthError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func validateEmail(_ email: String) throws {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.contains("@"), trimmed.contains(".") else {
            throw AuthError.invalidEmail
        }
    }

    private func validatePassword(_ password: String) throws {
        guard password.count >= 8 else { throw AuthError.weakPassword }
    }

    private static func topViewController() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              let root = scene.windows.first(where: \.isKeyWindow)?.rootViewController else {
            return nil
        }
        var top = root
        while let presented = top.presentedViewController {
            top = presented
        }
        return top
    }
}
