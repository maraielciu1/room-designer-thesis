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
            // Restore persisted mode (empty string = first launch)
            if !storedMode.isEmpty, let mode = AppMode(rawValue: storedMode) {
                selectedMode = mode
            }
        }
        .onChange(of: selectedMode) { _, newMode in
            if let newMode {
                storedMode = newMode.rawValue
            } else {
                storedMode = ""
            }
        }
    }

    // MARK: - Local Mode (original flow)

    private var localModeRoot: some View {
        NavigationView {
            LocalLandingView(switchMode: { selectedMode = nil })
        }
        .environmentObject(userManager)
        .environmentObject(catalogManager)
        .onAppear { ensureLocalManagers() }
        .modifier(ManagerEnvironmentModifier(
            roomManager: roomManager,
            historyManager: historyManager,
            scannedFurnitureManager: scannedFurnitureManager
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
            scannedFurnitureManager: scannedFurnitureManager
        ))
    }

    // MARK: - Helpers

    private func ensureLocalManagers() {
        if roomManager == nil { roomManager = RoomManager(userManager: userManager) }
        if historyManager == nil { historyManager = HistoryManager(userManager: userManager) }
        if scannedFurnitureManager == nil { scannedFurnitureManager = ScannedFurnitureManager(userManager: userManager) }
    }
}

// MARK: - Custom modifier to inject managers into environment

struct ManagerEnvironmentModifier: ViewModifier {
    let roomManager: RoomManager?
    let historyManager: HistoryManager?
    let scannedFurnitureManager: ScannedFurnitureManager?

    func body(content: Content) -> some View {
        Group {
            if let roomManager = roomManager,
               let historyManager = historyManager,
               let scannedFurnitureManager = scannedFurnitureManager {
                content
                    .environmentObject(roomManager)
                    .environmentObject(historyManager)
                    .environmentObject(scannedFurnitureManager)
            } else {
                content
            }
        }
    }
}
