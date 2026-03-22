//
//  LandingView.swift
//  RoomScanTest
//
//  Created by Mara Ielciu on 16.02.2026.
//
//  Local mode: bottom tab bar (Furniture, Rooms, Projects) + Marketplace in toolbar.
//

import SwiftUI

// MARK: - Local Landing View (bottom tab bar + Marketplace)

/// Main local-mode root. Same structure as MarketplaceTabRoot: VStack(content + tabBar) inside NavigationView.
struct LocalLandingView: View {
    var switchMode: () -> Void

    @EnvironmentObject var userManager: UserManager
    @State private var selectedTab: MainTab = .rooms

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                MainTabContent(selectedTab: selectedTab, switchMode: switchMode)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                MainTabBar(selection: $selectedTab)
            }
            .background(Color(hex: 0x0B0D17))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: switchMode) {
                        Image(systemName: "globe")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(AppTheme.accentGradientInline)
                    }
                    .accessibilityLabel("Switch to Marketplace")
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(hex: 0x0B0D17).opacity(0.60), for: .navigationBar)
            .toolbarBackgroundVisibility(.visible, for: .navigationBar)
        }
        .navigationViewStyle(.stack)
    }
}

// MARK: - Tab content (Furniture / Rooms / Projects)

private struct MainTabContent: View {
    let selectedTab: MainTab
    let switchMode: () -> Void

    var body: some View {
        Group {
            switch selectedTab {
            case .furniture: FurnitureLibraryView()
            case .rooms:     RoomListView()
            case .projects:  ProjectListView()
            }
        }
        .id(selectedTab)
        .animation(nil, value: selectedTab)
        .transaction { t in t.disablesAnimations = true }
    }
}

// MARK: - Legacy full-screen landing (kept for preview / reuse if needed)

struct LandingView: View {
    var switchMode: (() -> Void)? = nil

    @EnvironmentObject var userManager: UserManager
    @State private var showUserSelection = false
    @State private var logoScale: CGFloat = 0.6
    @State private var logoOpacity: Double = 0
    @State private var buttonsOffset: CGFloat = 40
    @State private var buttonsOpacity: Double = 0

    var body: some View {
        ZStack {
            AnimatedMeshBackground()
            VStack(spacing: 0) {
                Spacer()
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.glowCyan.opacity(0.12))
                            .frame(width: 140, height: 140)
                            .blur(radius: 30)
                        Image(systemName: "cube.transparent.fill")
                            .font(.system(size: 48, weight: .light))
                            .foregroundStyle(AppTheme.accentGradientInline)
                            .frame(width: 100, height: 100)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(
                                        LinearGradient(
                                            colors: [Color.white.opacity(0.25), Color.white.opacity(0.05)],
                                            startPoint: .topLeading, endPoint: .bottomTrailing
                                        ), lineWidth: 1
                                    )
                            )
                    }
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)
                    VStack(spacing: 8) {
                        Text("Room Designer")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("Transform your space with AR")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(AppTheme.secondaryText)
                    }
                    .opacity(logoOpacity)
                }
                Spacer().frame(height: 48)
                if let user = userManager.currentUser {
                    Button(action: { showUserSelection = true }) {
                        HStack(spacing: 10) {
                            Image(systemName: "person.crop.circle.fill")
                                .foregroundStyle(AppTheme.accentGradientInline)
                            Text(user.name)
                                .foregroundColor(.white.opacity(0.9))
                            Spacer()
                            Text("Switch")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(AppTheme.glowCyan)
                        }
                        .font(.subheadline)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .glassCard(cornerRadius: 14)
                    }
                    .padding(.horizontal, 36)
                    .opacity(buttonsOpacity)
                    .offset(y: buttonsOffset)
                }
                Spacer()
                VStack(spacing: 14) {
                    NavigationLink(destination: RoomListView()) {
                        landingCard(icon: "house.fill", iconTint: AppTheme.glowCyan, title: "My Rooms", subtitle: "View & edit scanned rooms")
                    }
                    NavigationLink(destination: FurnitureLibraryView()) {
                        landingCard(icon: "cube.fill", iconTint: AppTheme.glowBlue, title: "My Furniture", subtitle: "Scanned models & built-in library")
                    }
                    NavigationLink(destination: ProjectListView()) {
                        landingCard(icon: "folder.fill", iconTint: AppTheme.glowGreen, title: "My Projects", subtitle: "Group rooms into multi-room projects")
                    }
                }
                .padding(.horizontal, 24)
                .opacity(buttonsOpacity)
                .offset(y: buttonsOffset)
                Spacer().frame(height: 50)
            }
        }
        .sheet(isPresented: $showUserSelection) { UserSelectionView() }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.7).delay(0.1)) {
                logoScale = 1.0
                logoOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.6).delay(0.35)) {
                buttonsOffset = 0
                buttonsOpacity = 1.0
            }
        }
    }

    private func landingCard(icon: String, iconTint: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(iconTint)
                .frame(width: 40, height: 40)
                .background(iconTint.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(AppTheme.secondaryText)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppTheme.tertiaryText)
        }
        .padding(16)
        .glassCard(cornerRadius: AppTheme.cornerRadius)
    }
}

#Preview("Tab bar") {
    let userManager = UserManager()
    let roomManager = RoomManager(userManager: userManager)
    return LocalLandingView(switchMode: {})
        .environmentObject(userManager)
        .environmentObject(FurnitureCatalogManager())
        .environmentObject(ScannedFurnitureManager(userManager: userManager))
        .environmentObject(roomManager)
        .environmentObject(HistoryManager(userManager: userManager))
        .environmentObject(ProjectManager(userManager: userManager, roomManager: roomManager))
}

#Preview("Legacy landing") {
    NavigationView {
        LandingView()
            .environmentObject(UserManager())
    }
}
