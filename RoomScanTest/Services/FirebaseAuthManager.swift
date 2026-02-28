//
//  FirebaseAuthManager.swift
//  RoomScanTest
//
//  Created by Mara Ielciu on 28.02.2026.
//

import Foundation
import Combine
import FirebaseAuth

/// Manages Firebase Authentication state — sign-up, sign-in, sign-out,
/// and keeps the current `MarketplaceUser` profile in sync with Firestore.
@MainActor
class FirebaseAuthManager: ObservableObject {

    @Published var firebaseUser: FirebaseAuth.User?
    @Published var marketplaceUser: MarketplaceUser?
    @Published var isSignedIn = false
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var authListener: AuthStateDidChangeListenerHandle?

    init() {
        listenForAuthChanges()
    }

    deinit {
        if let handle = authListener {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }

    // MARK: - Auth State Listener

    private func listenForAuthChanges() {
        authListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.firebaseUser = user
                self?.isSignedIn = user != nil
                if let user {
                    await self?.fetchOrCreateProfile(for: user)
                } else {
                    self?.marketplaceUser = nil
                }
            }
        }
    }

    // MARK: - Email / Password

    func signUp(email: String, password: String, displayName: String) async {
        isLoading = true
        errorMessage = nil
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            // Update display name
            let changeRequest = result.user.createProfileChangeRequest()
            changeRequest.displayName = displayName
            try await changeRequest.commitChanges()

            // Reload to get updated profile
            try await result.user.reload()
            firebaseUser = Auth.auth().currentUser
            isSignedIn = true
            await fetchOrCreateProfile(for: result.user, preferredName: displayName)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            firebaseUser = result.user
            isSignedIn = true
            await fetchOrCreateProfile(for: result.user)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func signOut() {
        do {
            try Auth.auth().signOut()
            firebaseUser = nil
            marketplaceUser = nil
            isSignedIn = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func resetPassword(email: String) async {
        isLoading = true
        errorMessage = nil
        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Firestore Profile

    private func fetchOrCreateProfile(for user: FirebaseAuth.User, preferredName: String? = nil) async {
        let name = preferredName ?? user.displayName ?? user.email ?? "User"
        let profile = MarketplaceUser(
            id: user.uid,
            displayName: name,
            email: user.email ?? ""
        )
        // The MarketplaceManager will handle creating / fetching the Firestore document
        self.marketplaceUser = profile
    }
}
