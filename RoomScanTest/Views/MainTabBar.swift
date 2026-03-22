//
//  MainTabBar.swift
//  RoomScanTest
//
//  Bottom tab bar matching Marketplace style: ultraThinMaterial, icon + label.
//

import SwiftUI

enum MainTab: String, CaseIterable {
    case furniture = "Furniture"
    case rooms     = "Rooms"
    case projects  = "Projects"

    var icon: String {
        switch self {
        case .furniture: return "cube.fill"
        case .rooms:     return "house.fill"
        case .projects:  return "folder.fill"
        }
    }
}

struct MainTabBar: View {
    @Binding var selection: MainTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(MainTab.allCases, id: \.self) { tab in
                tabButton(tab)
            }
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

    private func tabButton(_ tab: MainTab) -> some View {
        let isSelected = selection == tab
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) { selection = tab }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.system(size: 20))
                    .foregroundStyle(
                        isSelected
                        ? AppTheme.accentGradientInline
                        : LinearGradient(colors: [AppTheme.tertiaryText], startPoint: .top, endPoint: .bottom)
                    )
                Text(tab.rawValue)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? AppTheme.glowCyan : AppTheme.tertiaryText)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
    }
}

#Preview {
    ZStack(alignment: .bottom) {
        Color(hex: 0x0B0D17).ignoresSafeArea()
        MainTabBar(selection: .constant(.rooms))
    }
    .preferredColorScheme(.dark)
}
