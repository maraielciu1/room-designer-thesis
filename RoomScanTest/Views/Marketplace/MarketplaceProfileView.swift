//
//  MarketplaceProfileView.swift
//  RoomScanTest
//
//  Created by Mara Ielciu on 28.02.2026.
//

import SwiftUI
import FirebaseAuth

/// Profile & settings view for the marketplace — shows user info, uploads, and sign-out.
struct MarketplaceProfileView: View {
    @EnvironmentObject var authManager: FirebaseAuthManager
    @EnvironmentObject var marketplaceManager: MarketplaceManager

    @Environment(\.dismiss) private var dismiss

    @State private var profile: MarketplaceUser?
    @State private var selectedItem: MarketplaceItem?

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: 0x0B0D17).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // ── Avatar / Name ──
                        profileHeader
                            .padding(.top, 20)

                        // ── Stats ──
                        statsRow

                        Divider().overlay(Color.white.opacity(0.08))
                            .padding(.horizontal, 16)

                        // ── My Uploads ──
                        VStack(alignment: .leading, spacing: 12) {
                            Text("My Uploads")
                                .font(.headline.weight(.semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)

                            if marketplaceManager.myUploads.isEmpty {
                                Text("You haven't uploaded anything yet.")
                                    .font(.caption)
                                    .foregroundColor(AppTheme.tertiaryText)
                                    .padding(.horizontal, 16)
                            } else {
                                LazyVGrid(columns: columns, spacing: 14) {
                                    ForEach(marketplaceManager.myUploads) { item in
                                        MarketplaceGridCard(item: item)
                                            .onTapGesture { selectedItem = item }
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }

                        Spacer().frame(height: 20)

                        // ── Actions ──
                        VStack(spacing: 12) {
                            Button {
                                authManager.signOut()
                                dismiss()
                            } label: {
                                HStack {
                                    Image(systemName: "rectangle.portrait.and.arrow.right")
                                    Text("Sign Out")
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(GhostButtonStyle())
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .tintedIcon()
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text("My Profile")
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.white)
                }
            }
        }
        .sheet(item: $selectedItem) { item in
            MarketplaceItemDetailView(item: item)
                .environmentObject(authManager)
                .environmentObject(marketplaceManager)
        }
        .task {
            guard let uid = authManager.firebaseUser?.uid else { return }
            profile = await marketplaceManager.fetchUserProfile(uid: uid)
            await marketplaceManager.fetchMyUploads(uid: uid)
        }
    }

    // MARK: - Profile Header

    private var profileHeader: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(AppTheme.glowViolet.opacity(0.15))
                    .frame(width: 90, height: 90)
                    .blur(radius: 20)

                Image(systemName: "person.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(AppTheme.accentGradientInline)
            }

            Text(profile?.displayName ?? authManager.marketplaceUser?.displayName ?? "User")
                .font(.title3.weight(.bold))
                .foregroundColor(.white)

            Text(profile?.email ?? authManager.firebaseUser?.email ?? "")
                .font(.caption)
                .foregroundColor(AppTheme.secondaryText)

            if let joined = profile?.joinedAt {
                Text("Joined \(joined, style: .date)")
                    .font(.caption2)
                    .foregroundColor(AppTheme.tertiaryText)
            }
        }
    }

    // MARK: - Stats

    private var statsRow: some View {
        HStack(spacing: 0) {
            statCard(value: "\(profile?.uploadCount ?? marketplaceManager.myUploads.count)",
                     label: "Uploads", icon: "icloud.and.arrow.up")
            Divider().frame(height: 40).overlay(Color.white.opacity(0.08))
            statCard(value: "\(profile?.totalDownloads ?? 0)",
                     label: "Downloads", icon: "arrow.down.circle")
        }
        .padding(.vertical, 12)
        .glassCard()
        .padding(.horizontal, 16)
    }

    private func statCard(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(AppTheme.accentGradientInline)
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundColor(.white)
            Text(label)
                .font(.caption2)
                .foregroundColor(AppTheme.tertiaryText)
        }
        .frame(maxWidth: .infinity)
    }
}
