//
//  UserSelectionView.swift
//  RoomScanTest
//
//  Created by Mara Ielciu on 16.02.2026.
//

import SwiftUI

struct UserSelectionView: View {
    @EnvironmentObject var userManager: UserManager
    @Environment(\.dismiss) var dismiss
    @State private var showCreateUser = false
    @State private var newUserName = ""
    @State private var newUserEmail = ""

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: 0x0B0D17).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 12) {
                        // ── Section: Users ──
                        ThemeSectionHeader(title: "Users", icon: "person.2.fill")
                            .padding(.horizontal, 20)
                            .padding(.top, 16)

                        ForEach(userManager.users) { user in
                            Button {
                                userManager.switchUser(user)
                                dismiss()
                            } label: {
                                HStack(spacing: 14) {
                                    // Avatar
                                    ZStack {
                                        Circle()
                                            .fill(userManager.currentUser?.id == user.id
                                                  ? AppTheme.glowCyan.opacity(0.15)
                                                  : Color.white.opacity(0.06))
                                            .frame(width: 44, height: 44)
                                        Text(String(user.name.prefix(1)).uppercased())
                                            .font(.headline.weight(.bold))
                                            .foregroundStyle(
                                                userManager.currentUser?.id == user.id
                                                ? AppTheme.accentGradientInline
                                                : LinearGradient(colors: [.gray], startPoint: .top, endPoint: .bottom)
                                            )
                                    }

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(user.name)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundColor(.white)
                                        Text(user.email)
                                            .font(.caption)
                                            .foregroundColor(AppTheme.secondaryText)
                                    }

                                    Spacer()

                                    if userManager.currentUser?.id == user.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(AppTheme.accentGradientInline)
                                            .font(.title3)
                                    }
                                }
                                .padding(14)
                                .glassCard(cornerRadius: AppTheme.cardCornerRadius)
                            }
                            .padding(.horizontal, 16)
                        }

                        // ── Create New ──
                        Button(action: { showCreateUser = true }) {
                            HStack(spacing: 10) {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(AppTheme.accentGradientInline)
                                Text("Create New User")
                                    .foregroundColor(.white.opacity(0.85))
                            }
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(14)
                            .background(Color.white.opacity(0.04))
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius))
                            .overlay(
                                RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius)
                                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
                                    .foregroundColor(Color.white.opacity(0.10))
                            )
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    }
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("Select User")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(AppTheme.glowCyan)
                }
            }
            .alert("Create New User", isPresented: $showCreateUser) {
                TextField("Name", text: $newUserName)
                TextField("Email", text: $newUserEmail)
                    .keyboardType(.emailAddress)
                Button("Cancel", role: .cancel) {
                    newUserName = ""
                    newUserEmail = ""
                }
                Button("Create") {
                    if !newUserName.isEmpty {
                        let user = userManager.createUser(
                            name: newUserName,
                            email: newUserEmail.isEmpty
                                ? "\(newUserName.lowercased())@example.com"
                                : newUserEmail
                        )
                        userManager.setCurrentUser(user)
                        newUserName = ""
                        newUserEmail = ""
                        dismiss()
                    }
                }
            } message: {
                Text("Enter user details")
            }
        }
    }
}

#Preview {
    UserSelectionView()
        .environmentObject(UserManager())
        .preferredColorScheme(.dark)
}
