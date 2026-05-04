//
//  RoomScanTestApp.swift
//  RoomScanTest
//
//  Created by Mara Ielciu on 16.02.2026.
//

import SwiftUI

// MARK: - App Entry Point

@main
struct RoomScanTestApp: App {
    init() {
        configureNavigationBar()
    }

    private func configureNavigationBar() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(AppTheme.background)
        appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().tintColor = UIColor(AppTheme.accentLight)
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .preferredColorScheme(.dark)
        }
    }
}

// MARK: - Root View

struct AppRootView: View {
    @StateObject private var userManager = UserManager()
    @StateObject private var catalogManager = FurnitureCatalogManager()

    @State private var roomManager: RoomManager?
    @State private var historyManager: HistoryManager?
    @State private var scannedFurnitureManager: ScannedFurnitureManager?
    @State private var projectManager: ProjectManager?

    @State private var showSplash = true

    var body: some View {
        Group {
            if showSplash {
                AppSplashView { showSplash = false }
                    .transition(.opacity)
            } else {
                LocalLandingView()
                    .environmentObject(userManager)
                    .environmentObject(catalogManager)
                    .modifier(ManagerEnvironmentModifier(
                        roomManager: roomManager,
                        historyManager: historyManager,
                        scannedFurnitureManager: scannedFurnitureManager,
                        projectManager: projectManager
                    ))
            }
        }
        .animation(.easeInOut(duration: 0.4), value: showSplash)
        .onAppear {
            ensureLocalManagers()
        }
    }

    private func ensureLocalManagers() {
        if roomManager == nil { roomManager = RoomManager(userManager: userManager) }
        if historyManager == nil { historyManager = HistoryManager(userManager: userManager) }
        if scannedFurnitureManager == nil { scannedFurnitureManager = ScannedFurnitureManager(userManager: userManager) }
        if projectManager == nil, let rm = roomManager {
            projectManager = ProjectManager(userManager: userManager, roomManager: rm)
        }
    }
}

// MARK: - Custom modifier to inject managers into environment

struct ManagerEnvironmentModifier: ViewModifier {
    let roomManager: RoomManager?
    let historyManager: HistoryManager?
    let scannedFurnitureManager: ScannedFurnitureManager?
    let projectManager: ProjectManager?

    func body(content: Content) -> some View {
        Group {
            if let roomManager = roomManager,
               let historyManager = historyManager,
               let scannedFurnitureManager = scannedFurnitureManager,
               let projectManager = projectManager {
                content
                    .environmentObject(roomManager)
                    .environmentObject(historyManager)
                    .environmentObject(scannedFurnitureManager)
                    .environmentObject(projectManager)
            } else {
                content
            }
        }
    }
}
