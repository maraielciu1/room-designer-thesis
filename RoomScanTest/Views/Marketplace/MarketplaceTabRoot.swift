//
//  MarketplaceTabRoot.swift
//  RoomScanTest
//
//  Created by Mara Ielciu on 28.02.2026.
//

import SwiftUI

/// Root container for the Marketplace mode — provides tabs for browsing, local rooms, and the library.
struct MarketplaceTabRoot: View {
    var switchMode: () -> Void

    @EnvironmentObject var authManager: FirebaseAuthManager
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            // ── Content for selected tab ──
            Group {
                switch selectedTab {
                case 0:
                    MarketplaceHomeView()
                case 1:
                    RoomListView()
                case 2:
                    FurnitureLibraryView()
                default:
                    MarketplaceHomeView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // ── Custom Tab Bar ──
            tabBar
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    switchMode()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.left")
                        Text("Local")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundColor(AppTheme.glowCyan)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            tabButton(icon: "globe", label: "Marketplace", index: 0)
            tabButton(icon: "house.fill", label: "My Rooms", index: 1)
            tabButton(icon: "cube.fill", label: "Library", index: 2)
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(.ultraThinMaterial)
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color.white.opacity(0.08)),
            alignment: .top
        )
    }

    private func tabButton(icon: String, label: String, index: Int) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) { selectedTab = index }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(
                        selectedTab == index
                        ? AppTheme.accentGradientInline
                        : LinearGradient(colors: [AppTheme.tertiaryText], startPoint: .top, endPoint: .bottom)
                    )
                Text(label)
                    .font(.system(size: 10, weight: selectedTab == index ? .semibold : .regular))
                    .foregroundColor(selectedTab == index ? AppTheme.glowCyan : AppTheme.tertiaryText)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
    }
}
