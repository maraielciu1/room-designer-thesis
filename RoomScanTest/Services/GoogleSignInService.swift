//
//  GoogleSignInService.swift
//  RoomScanTest
//

import UIKit

#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

struct GoogleProfile {
    let userId: String
    let name: String
    let email: String
}

enum GoogleSignInService {
    static var isAvailable: Bool {
        #if canImport(GoogleSignIn)
        return true
        #else
        return false
        #endif
    }

    @MainActor
    static func signIn(presenting viewController: UIViewController) async throws -> GoogleProfile {
        #if canImport(GoogleSignIn)
        return try await withCheckedThrowingContinuation { continuation in
            GIDSignIn.sharedInstance.signIn(withPresenting: viewController) { result, error in
                if let error {
                    continuation.resume(throwing: AuthError.googleSignInFailed(error.localizedDescription))
                    return
                }
                guard let user = result?.user,
                      let profile = user.profile else {
                    continuation.resume(throwing: AuthError.googleSignInFailed("No Google profile returned."))
                    return
                }
                continuation.resume(returning: GoogleProfile(
                    userId: user.userID ?? profile.email,
                    name: profile.name,
                    email: profile.email
                ))
            }
        }
        #else
        throw AuthError.googleSignInUnavailable
        #endif
    }

    @MainActor
    static func configureIfNeeded() {
        #if canImport(GoogleSignIn)
        // Reads GIDClientID from Info.plist when present.
        if GIDSignIn.sharedInstance.configuration == nil,
           let clientID = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String,
           !clientID.isEmpty,
           !clientID.contains("REPLACE") {
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        }
        #endif
    }

    static func signOut() {
        #if canImport(GoogleSignIn)
        GIDSignIn.sharedInstance.signOut()
        #endif
    }
}
