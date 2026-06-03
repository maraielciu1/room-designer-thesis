//
//  UserSelectionView.swift
//  RoomScanTest
//
//  Legacy name — opens the signed-in account sheet.
//

import SwiftUI
import SwiftData

struct UserSelectionView: View {
    @EnvironmentObject var userManager: UserManager
    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        AccountView(authManager: authManager)
            .environmentObject(userManager)
    }
}

#Preview {
    let um = UserManager()
    let container = try! ModelContainer(for: AppUserEntity.self)
    return UserSelectionView()
        .environmentObject(um)
        .environmentObject(AuthenticationManager(modelContainer: container, userManager: um))
        .preferredColorScheme(.dark)
}
