//
//  RoomScanTestApp.swift
//  RoomScanTest
//
//  Created by Mara Ielciu on 16.02.2026.
//

import SwiftUI

@main
struct RoomScanTestApp: App {
    var body: some Scene {
        WindowGroup {
            AppRootView()
        }
    }
}

struct AppRootView: View {
    @StateObject private var userManager = UserManager()
    @StateObject private var catalogManager = FurnitureCatalogManager()
    
    // Store managers as @State to prevent recreation
    @State private var roomManager: RoomManager?
    @State private var historyManager: HistoryManager?
    @State private var scannedFurnitureManager: ScannedFurnitureManager?
    
    var body: some View {
        NavigationView {
            LandingView()
        }
        .environmentObject(userManager)
        .environmentObject(catalogManager)
        .onAppear {
            // Initialize managers only once - this prevents recreation on every render
            if roomManager == nil {
                roomManager = RoomManager(userManager: userManager)
            }
            if historyManager == nil {
                historyManager = HistoryManager(userManager: userManager)
            }
            if scannedFurnitureManager == nil {
                scannedFurnitureManager = ScannedFurnitureManager(userManager: userManager)
            }
        }
        .modifier(ManagerEnvironmentModifier(
            roomManager: roomManager,
            historyManager: historyManager,
            scannedFurnitureManager: scannedFurnitureManager
        ))
    }
}

// Custom modifier to inject managers into environment
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
