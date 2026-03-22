//
//  RoomScanTestApp.swift
//  RoomScanTest
//
//  Created by Mara Ielciu on 16.02.2026.
//

import SwiftUI
import FirebaseCore

// MARK: - Firebase Configuration

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        return true
    }
}

// MARK: - App Entry Point

@main
struct RoomScanTestApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .preferredColorScheme(.dark)
        }
    }
}

// MARK: - Root View — Mode Selection + Routing

struct AppRootView: View {
    // Local-mode managers (always created — lightweight)
    @StateObject private var userManager = UserManager()
    @StateObject private var catalogManager = FurnitureCatalogManager()

    // Marketplace-mode managers
    @StateObject private var authManager = FirebaseAuthManager()
    @StateObject private var marketplaceManager = MarketplaceManager()

    // Store managers as @State to prevent recreation
    @State private var roomManager: RoomManager?
    @State private var historyManager: HistoryManager?
    @State private var scannedFurnitureManager: ScannedFurnitureManager?
    @State private var projectManager: ProjectManager?

    // Persisted mode selection (nil = show picker)
    @AppStorage("selectedAppMode") private var storedMode: String = ""
    @State private var selectedMode: AppMode?

    var body: some View {
        Group {
            if let mode = selectedMode {
                switch mode {
                case .local:
                    localModeRoot
                case .marketplace:
                    marketplaceModeRoot
                }
            } else {
                ModeSelectionView(selectedMode: $selectedMode)
            }
        }
        .onAppear {
            // Create managers immediately so they exist before any tab (Local or Marketplace) is shown.
            ensureLocalManagers()
            // Restore persisted mode (empty string = first launch).
            if !storedMode.isEmpty, let mode = AppMode(rawValue: storedMode) {
                selectedMode = mode
            }
        }
        .onChange(of: selectedMode) { _, newMode in
            if let newMode {
                storedMode = newMode.rawValue
                // Create managers as soon as we switch to a mode that needs them,
                // so they're available on first render (avoid "No ObservableObject" crash).
                ensureLocalManagers()
            } else {
                storedMode = ""
            }
        }
    }

    // MARK: - Local Mode (original flow)

    private var localModeRoot: some View {
        LocalLandingView(switchMode: { selectedMode = nil })
            .environmentObject(userManager)
            .environmentObject(catalogManager)
            .onAppear { ensureLocalManagers() }
            .modifier(ManagerEnvironmentModifier(
                roomManager: roomManager,
                historyManager: historyManager,
                scannedFurnitureManager: scannedFurnitureManager,
                projectManager: projectManager
            ))
    }

    // MARK: - Marketplace Mode (Firebase flow)

    private var marketplaceModeRoot: some View {
        NavigationView {
            if authManager.isSignedIn {
                MarketplaceTabRoot(switchMode: { selectedMode = nil })
            } else {
                MarketplaceAuthView()
            }
        }
        .environmentObject(authManager)
        .environmentObject(marketplaceManager)
        // Also provide local managers so marketplace users can access room scanning
        .environmentObject(userManager)
        .environmentObject(catalogManager)
        .onAppear { ensureLocalManagers() }
        .modifier(ManagerEnvironmentModifier(
            roomManager: roomManager,
            historyManager: historyManager,
            scannedFurnitureManager: scannedFurnitureManager,
            projectManager: projectManager
        ))
    }

    // MARK: - Helpers

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
