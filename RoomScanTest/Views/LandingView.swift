// LandingView.swift
// RoomScanTest
//
// Local mode root: floating pill tab bar, static background.

import SwiftUI

// MARK: - Local Landing View

struct LocalLandingView: View {
    @EnvironmentObject var userManager: UserManager
    @State private var selectedTab: MainTab = .rooms

    var body: some View {
        // Tab roots set their own title display mode (lists use `.inline` so titles stay visible).
        NavigationStack {
            MainTabContent(selectedTab: selectedTab)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppTheme.background.ignoresSafeArea())
                .safeAreaInset(edge: .bottom) {
                    MainTabBar(selection: $selectedTab)
                        .padding(.bottom, 20)
                        .frame(maxWidth: .infinity)
                        .background(Color.clear)
                }
                .toolbarBackground(AppTheme.background, for: .navigationBar)
                .toolbarBackgroundVisibility(.visible, for: .navigationBar)
                .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}

// MARK: - Tab content

private struct MainTabContent: View {
    let selectedTab: MainTab

    var body: some View {
        Group {
            switch selectedTab {
            case .furniture: FurnitureLibraryView()
            case .rooms:     RoomListView()
            case .projects:  ProjectListView()
            }
        }
        .animation(nil, value: selectedTab)
        .transaction { t in t.disablesAnimations = true }
    }
}

// MARK: - Legacy landing (kept for preview reuse)

struct LandingView: View {
    @EnvironmentObject var userManager: UserManager
    @State private var showUserSelection = false
    @State private var logoScale: CGFloat = 0.6
    @State private var logoOpacity: Double = 0
    @State private var buttonsOffset: CGFloat = 40
    @State private var buttonsOpacity: Double = 0

    var body: some View {
        ZStack {
            // Static background on content screens
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.accentMuted)
                            .frame(width: 140, height: 140)
                            .blur(radius: 30)
                        Image(systemName: "cube.transparent.fill")
                            .font(.system(size: 48, weight: .light))
                            .foregroundStyle(AppTheme.accentGradient)
                            .frame(width: 100, height: 100)
                            .background(AppTheme.surfacePrimary)
                            .clipShape(Circle())
                            .overlay(
                                Circle().strokeBorder(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.20), Color.white.opacity(0.04)],
                                        startPoint: .topLeading, endPoint: .bottomTrailing),
                                    lineWidth: 1)
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
                                .foregroundStyle(AppTheme.accentGradient)
                            Text(user.name)
                                .foregroundColor(AppTheme.primaryText)
                            Spacer()
                            Text("Switch")
                                .font(.appCaption2.weight(.semibold))
                                .foregroundColor(AppTheme.accentLight)
                        }
                        .font(.appCallout)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .classicCard(cornerRadius: 14)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 36)
                    .opacity(buttonsOpacity)
                    .offset(y: buttonsOffset)
                }

                Spacer()

                VStack(spacing: 12) {
                    NavigationLink(destination: RoomListView()) {
                        landingCard(icon: "house.fill", tint: AppTheme.accent,
                                    title: "My Rooms", subtitle: "View & edit scanned rooms")
                    }
                    NavigationLink(destination: FurnitureLibraryView()) {
                        landingCard(icon: "cube.fill", tint: AppTheme.accentLight,
                                    title: "My Furniture", subtitle: "Scanned models & built-in library")
                    }
                    NavigationLink(destination: ProjectListView()) {
                        landingCard(icon: "folder.fill", tint: AppTheme.glowGreen,
                                    title: "My Projects", subtitle: "Group rooms into projects")
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
                logoScale = 1.0; logoOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.6).delay(0.35)) {
                buttonsOffset = 0; buttonsOpacity = 1.0
            }
        }
    }

    private func landingCard(icon: String, tint: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(tint.opacity(0.14))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(tint)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.appHeadline)
                    .foregroundColor(AppTheme.primaryText)
                Text(subtitle)
                    .font(.appCaption)
                    .foregroundColor(AppTheme.tertiaryText)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppTheme.tertiaryText)
        }
        .padding(16)
        .classicCard(cornerRadius: AppTheme.cornerRadius)
    }
}

#Preview("Tab bar") {
    let userManager = UserManager()
    let roomManager = RoomManager(userManager: userManager)
    return LocalLandingView()
        .environmentObject(userManager)
        .environmentObject(FurnitureCatalogManager())
        .environmentObject(ScannedFurnitureManager(userManager: userManager))
        .environmentObject(roomManager)
        .environmentObject(HistoryManager(userManager: userManager))
        .environmentObject(ProjectManager(userManager: userManager, roomManager: roomManager))
}

#Preview("Legacy landing") {
    NavigationView { LandingView().environmentObject(UserManager()) }
}
