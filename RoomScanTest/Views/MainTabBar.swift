// MainTabBar.swift
// RoomScanTest
//
// Floating pill tab bar — centred, capsule-shaped, sliding indicator,
// refined indigo accent, opaque material background.

import SwiftUI

enum MainTab: String, CaseIterable {
    case furniture = "Furniture"
    case rooms     = "Rooms"
    case projects  = "Projects"

    var icon: String        { iconFor(selected: false) }
    var iconSelected: String { iconFor(selected: true) }

    private func iconFor(selected: Bool) -> String {
        switch self {
        case .furniture: return selected ? "cube.fill"       : "cube"
        case .rooms:     return selected ? "house.fill"      : "house"
        case .projects:  return selected ? "folder.fill"     : "folder"
        }
    }
}

struct MainTabBar: View {
    @Binding var selection: MainTab
    @Namespace private var indicator

    var body: some View {
        HStack(spacing: 2) {
            ForEach(MainTab.allCases, id: \.self) { tab in
                tabButton(tab)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
        .background(AppTheme.surfacePrimary.opacity(0.97), in: Capsule())
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
        .shadow(color: .black.opacity(0.45), radius: 28, y: 10)
        .shadow(color: AppTheme.glowAccent, radius: 18, y: 4)
        .fixedSize(horizontal: true, vertical: true)
    }

    private func tabButton(_ tab: MainTab) -> some View {
        let isSelected = selection == tab

        return Button {
            let haptic = UIImpactFeedbackGenerator(style: .light)
            haptic.impactOccurred()
            withAnimation(.spring(response: 0.34, dampingFraction: 0.76)) {
                selection = tab
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: isSelected ? tab.iconSelected : tab.icon)
                    .font(.system(size: 18, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? AppTheme.accentGradient : LinearGradient(
                        colors: [AppTheme.tabBarItemInactive],
                        startPoint: .top, endPoint: .bottom))
                    .scaleEffect(isSelected ? 1.05 : 1.0)
                    .animation(.spring(response: 0.28, dampingFraction: 0.7), value: isSelected)

                Text(tab.rawValue)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? AppTheme.accentLight : AppTheme.tabBarItemInactive)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 9)
            .background {
                if isSelected {
                    Capsule()
                        .fill(AppTheme.accentMuted)
                        .overlay(
                            Capsule().strokeBorder(
                                AppTheme.accent.opacity(0.25), lineWidth: 1)
                        )
                        .matchedGeometryEffect(id: "tabPill", in: indicator)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ZStack {
        AppTheme.background.ignoresSafeArea()
        VStack {
            Spacer()
            MainTabBar(selection: .constant(.rooms))
                .padding(.bottom, 32)
        }
    }
    .preferredColorScheme(.dark)
}
