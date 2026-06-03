//
//  AccountView.swift
//  RoomScanTest
//

import SwiftUI

struct AccountView: View {
    @EnvironmentObject var userManager: UserManager
    @ObservedObject var authManager: AuthenticationManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        if let user = userManager.currentUser {
                            profileCard(user: user)
                            dataSummaryCard
                        }

                        Button(role: .destructive) {
                            authManager.signOut()
                            dismiss()
                        } label: {
                            HStack {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                Text("Sign Out")
                            }
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(14)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    }
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .appNavigationChrome()
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(AppTheme.warmAccent)
                }
            }
            .appSheetBackground()
        }
    }

    private func profileCard(user: User) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ThemeSectionHeader(title: "Profile", icon: "person.crop.circle.fill")
                .padding(.horizontal, 4)

            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(AppTheme.glowCyan.opacity(0.15))
                        .frame(width: 52, height: 52)
                    Text(String(user.name.prefix(1)).uppercased())
                        .font(.title3.weight(.bold))
                        .foregroundStyle(AppTheme.accentGradientInline)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(user.name)
                        .font(.headline)
                        .foregroundStyle(AppTheme.primaryText)
                    Text(user.email)
                        .font(.caption)
                        .foregroundColor(AppTheme.secondaryText)
                    Label(
                        user.authProvider == .google ? "Google account" : "Email account",
                        systemImage: user.authProvider == .google ? "g.circle" : "envelope.fill"
                    )
                    .font(.caption2)
                    .foregroundColor(AppTheme.secondaryText.opacity(0.9))
                }
                Spacer()
            }
            .padding(16)
            .glassCard(cornerRadius: AppTheme.cardCornerRadius)
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    private var dataSummaryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            ThemeSectionHeader(title: "Your data", icon: "lock.shield.fill")
                .padding(.horizontal, 4)
            Text("Rooms, projects, and scanned objects are stored on this device and linked to your account. Other users cannot see your data.")
                .font(.caption)
                .foregroundColor(AppTheme.secondaryText)
                .padding(.horizontal, 4)
        }
        .padding(.horizontal, 16)
    }
}
