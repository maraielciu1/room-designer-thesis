//
//  RoomScanTestApp.swift
//  RoomScanTest
//
//  Created by Mara Ielciu on 16.02.2026.
//

import SwiftUI
import SwiftData

// MARK: - App Entry Point

@main
struct RoomScanTestApp: App {
    private let modelContainer: ModelContainer
    @StateObject private var userManager: UserManager
    @StateObject private var authManager: AuthenticationManager

    init() {
        let container: ModelContainer
        do {
            container = try ModelContainer(for:
                AppUserEntity.self,
                RoomEntity.self,
                FurnitureReplacementEntity.self,
                ProjectEntity.self,
                ScannedFurnitureEntity.self,
                ReplacementHistoryEntity.self
            )
        } catch {
            fatalError("Failed to create SwiftData container: \(error)")
        }
        modelContainer = container
        let um = UserManager()
        _userManager = StateObject(wrappedValue: um)
        _authManager = StateObject(
            wrappedValue: AuthenticationManager(modelContainer: container, userManager: um)
        )
        Self.configureNavigationBar()
    }

    private static func configureNavigationBar() {
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor(AppTheme.lightNeutral)
        ]
        let largeTitleAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor(AppTheme.lightNeutral),
            .font: UIFont.systemFont(ofSize: 34, weight: .bold)
        ]

        let standard = UINavigationBarAppearance()
        standard.configureWithOpaqueBackground()
        standard.backgroundColor = UIColor(AppTheme.background)
        standard.titleTextAttributes = titleAttrs
        standard.largeTitleTextAttributes = largeTitleAttrs

        let scrollEdge = UINavigationBarAppearance()
        scrollEdge.configureWithTransparentBackground()
        scrollEdge.backgroundColor = .clear
        scrollEdge.shadowColor = .clear
        scrollEdge.titleTextAttributes = titleAttrs
        scrollEdge.largeTitleTextAttributes = largeTitleAttrs

        UINavigationBar.appearance().standardAppearance = standard
        UINavigationBar.appearance().compactAppearance = standard
        UINavigationBar.appearance().scrollEdgeAppearance = scrollEdge
        UINavigationBar.appearance().tintColor = UIColor(AppTheme.lightNeutral)
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(userManager)
                .environmentObject(authManager)
                .modelContainer(modelContainer)
                .preferredColorScheme(.dark)
                .onOpenURL { url in
                    #if canImport(GoogleSignIn)
                    GIDSignIn.sharedInstance.handle(url)
                    #endif
                }
        }
    }
}

// MARK: - Root View

struct AppRootView: View {
    @EnvironmentObject var userManager: UserManager
    @EnvironmentObject var authManager: AuthenticationManager
    @StateObject private var catalogManager = FurnitureCatalogManager()

    @Environment(\.modelContext) private var modelContext

    @State private var roomManager: RoomManager?
    @State private var historyManager: HistoryManager?
    @State private var scannedFurnitureManager: ScannedFurnitureManager?
    @State private var projectManager: ProjectManager?

    @State private var showSplash = true

    var body: some View {
        Group {
            if showSplash {
                AppSplashView { finishSplash() }
                    .transition(.opacity)
            } else if !authManager.isAuthenticated {
                AuthenticationView(authManager: authManager)
                    .transition(.opacity)
            } else {
                AuthenticatedShell(
                    roomManager: $roomManager,
                    historyManager: $historyManager,
                    scannedFurnitureManager: $scannedFurnitureManager,
                    projectManager: $projectManager
                )
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
        .animation(.easeInOut(duration: 0.35), value: authManager.isAuthenticated)
        .onAppear {
            authManager.onAuthStateChanged = { syncManagersAfterAuthChange() }
        }
    }

    private func finishSplash() {
        authManager.restoreSession()
        syncManagersAfterAuthChange()
        showSplash = false
    }

    private func syncManagersAfterAuthChange() {
        if authManager.isAuthenticated {
            // Migration MUST run before managers are created. RoomManager.init calls
            // cleanOrphanedScanFiles — if SwiftData is empty (first launch after migration)
            // it would treat every scan file as orphaned and delete them all.
            SwiftDataMigration.runIfNeeded(modelContext: modelContext, userManager: userManager)
            ensureManagers()
            roomManager?.reloadForCurrentUser()
            historyManager?.reloadForCurrentUser()
            scannedFurnitureManager?.reloadForCurrentUser()
            projectManager?.reloadForCurrentUser()
        } else {
            roomManager = nil
            historyManager = nil
            scannedFurnitureManager = nil
            projectManager = nil
        }
    }

    private func ensureManagers() {
        if roomManager == nil { roomManager = RoomManager(userManager: userManager, modelContext: modelContext) }
        if historyManager == nil { historyManager = HistoryManager(userManager: userManager, modelContext: modelContext) }
        if scannedFurnitureManager == nil {
            scannedFurnitureManager = ScannedFurnitureManager(userManager: userManager, modelContext: modelContext)
        }
        if projectManager == nil, let rm = roomManager {
            projectManager = ProjectManager(userManager: userManager, roomManager: rm, modelContext: modelContext)
        }
    }
}

// MARK: - Authenticated main UI

private struct AuthenticatedShell: View {
    @EnvironmentObject var userManager: UserManager
    @EnvironmentObject var authManager: AuthenticationManager
    @Binding var roomManager: RoomManager?
    @Binding var historyManager: HistoryManager?
    @Binding var scannedFurnitureManager: ScannedFurnitureManager?
    @Binding var projectManager: ProjectManager?

    @State private var showAccount = false

    var body: some View {
        LocalLandingView(showAccount: $showAccount)
            .sheet(isPresented: $showAccount) {
                AccountView(authManager: authManager)
                    .environmentObject(userManager)
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

#if canImport(GoogleSignIn)
import GoogleSignIn
#endif
