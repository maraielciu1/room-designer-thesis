// AppTheme.swift
// RoomScanTest
//
// App-wide design system — deep blue-gray palette with warm clay accents.

import SwiftUI

// MARK: - Colour Palette

enum AppTheme {

    // ── Core brand (canonical) ─────────────────────────────────────────────────
    /// #1B3C53
    static let primaryDark   = Color(hex: 0x1B3C53)
    /// #456882
    static let secondaryTint = Color(hex: 0x456882)
    /// #D2C1B6
    static let warmAccent    = Color(hex: 0xD2C1B6)
    /// #F9F3EF
    static let lightNeutral  = Color(hex: 0xF9F3EF)

    // ── Backgrounds & surfaces ─────────────────────────────────────────────────
    static let background       = primaryDark
    static let surfacePrimary   = Color(hex: 0x152E42)
    static let surfaceSecondary = secondaryTint
    static let surfaceTertiary  = secondaryTint.opacity(0.72)

    // ── Accent ────────────────────────────────────────────────────────────────
    static let accent      = warmAccent
    static let accentLight = lightNeutral
    static let accentMuted = warmAccent.opacity(0.18)

    static let accentGradient = LinearGradient(
        colors: [warmAccent, secondaryTint],
        startPoint: .topLeading,
        endPoint: .bottomTrailing)

    static let accentGradientInline = accentGradient
    static let glowBlue   = secondaryTint
    static let glowCyan   = secondaryTint
    static let glowViolet = warmAccent

    // ── Status (semantic, palette-adjacent) ───────────────────────────────────
    static let glowGreen  = Color(hex: 0x6B9B7A)
    static let glowOrange = warmAccent
    static let glowRed    = Color(hex: 0xC47A6E)

    // ── Text ──────────────────────────────────────────────────────────────────
    static let primaryText   = lightNeutral
    static let secondaryText = lightNeutral.opacity(0.72)
    static let tertiaryText  = warmAccent.opacity(0.85)

    // ── Glow / chrome ─────────────────────────────────────────────────────────
    static let glowAccent = warmAccent.opacity(0.28)

    // ── Tab bar ───────────────────────────────────────────────────────────────
    static let tabBarBackground   = primaryDark
    static let tabBarItemInactive = lightNeutral.opacity(0.45)
    static let tabBarItemActive   = lightNeutral
    static let tabBarPill         = warmAccent.opacity(0.16)

    // ── Sizes ─────────────────────────────────────────────────────────────────
    static let cornerRadius:       CGFloat = 18
    static let cardCornerRadius:   CGFloat = 16
    static let buttonCornerRadius: CGFloat = 14

    // ── Page background ─────────────────────────────────────────────────────────
    static let pageBackground = LinearGradient(
        colors: [primaryDark, Color(hex: 0x142A3C)],
        startPoint: .top,
        endPoint: .bottom)
}

// MARK: - Hex Colour Convenience

extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red:   Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8)  & 0xFF) / 255,
            blue:  Double( hex        & 0xFF) / 255,
            opacity: alpha
        )
    }
}

// MARK: - Screen Chrome

struct AppScreenBackground: View {
    var body: some View {
        AppTheme.background.ignoresSafeArea()
    }
}

struct AppTopBarBackground: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
            AppTheme.primaryDark.opacity(0.78)
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppTheme.warmAccent.opacity(0.22))
                .frame(height: 0.5)
        }
    }
}

// MARK: - Typography

extension Font {
    static let appLargeTitle = Font.system(size: 34, weight: .bold)
    static let appTitle      = Font.system(size: 28, weight: .bold)
    static let appTitle2     = Font.system(size: 22, weight: .semibold)
    static let appHeadline   = Font.system(size: 17, weight: .semibold)
    static let appBody       = Font.system(size: 16, weight: .regular)
    static let appCallout    = Font.system(size: 15, weight: .regular)
    static let appCaption    = Font.system(size: 13, weight: .regular)
    static let appCaption2   = Font.system(size: 11, weight: .medium)
}

// MARK: - Card / Panel Surfaces

struct AppPanelCard: ViewModifier {
    var cornerRadius: CGFloat = AppTheme.cardCornerRadius

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(AppTheme.primaryDark.opacity(0.82))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(AppTheme.warmAccent.opacity(0.28), lineWidth: 1)
            )
    }
}

struct ClassicCard: ViewModifier {
    var cornerRadius: CGFloat = AppTheme.cardCornerRadius

    func body(content: Content) -> some View {
        content.modifier(AppPanelCard(cornerRadius: cornerRadius))
    }
}

struct GlassCard: ViewModifier {
    var cornerRadius: CGFloat = AppTheme.cardCornerRadius

    func body(content: Content) -> some View {
        content.modifier(AppPanelCard(cornerRadius: cornerRadius))
    }
}

// MARK: - Button Styles

struct GradientButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.appHeadline)
            .foregroundStyle(AppTheme.primaryDark)
            .padding(.horizontal, 28)
            .padding(.vertical, 15)
            .background(
                AppTheme.warmAccent.opacity(configuration.isPressed ? 0.82 : 1)
            )
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(AppTheme.lightNeutral.opacity(0.35), lineWidth: 1))
            .shadow(color: AppTheme.glowAccent, radius: configuration.isPressed ? 4 : 10, y: 4)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct SecondaryChipButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.semibold))
            .foregroundStyle(AppTheme.lightNeutral)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: AppTheme.buttonCornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: AppTheme.buttonCornerRadius, style: .continuous)
                        .fill(AppTheme.secondaryTint.opacity(configuration.isPressed ? 0.75 : 0.92))
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.buttonCornerRadius, style: .continuous)
                    .strokeBorder(AppTheme.warmAccent.opacity(0.3), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

/// Secondary ghost pill — for less important actions.
struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.appCallout.weight(.semibold))
            .foregroundStyle(AppTheme.secondaryText)
            .padding(.horizontal, 22)
            .padding(.vertical, 12)
            .background {
                ZStack {
                    Capsule().fill(.ultraThinMaterial)
                    Capsule().fill(AppTheme.secondaryTint.opacity(configuration.isPressed ? 0.7 : 0.85))
                }
            }
            .overlay(Capsule().strokeBorder(AppTheme.warmAccent.opacity(0.25), lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Icon Button Modifiers

struct AppIconButton: ViewModifier {
    var prominent: Bool = false
    var tint: Color = AppTheme.lightNeutral

    func body(content: Content) -> some View {
        content
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: 40, height: 40)
            .background {
                ZStack {
                    Circle().fill(.ultraThinMaterial)
                    Circle().fill(
                        prominent
                            ? AppTheme.secondaryTint.opacity(0.95)
                            : AppTheme.primaryDark.opacity(0.88)
                    )
                }
            }
            .overlay(Circle().strokeBorder(AppTheme.warmAccent.opacity(0.35), lineWidth: 1))
    }
}

struct TintedIconButton: ViewModifier {
    var tint: Color = AppTheme.lightNeutral

    func body(content: Content) -> some View {
        content.modifier(AppIconButton(tint: tint))
    }
}

struct TintedIconGradientButton: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(AppTheme.primaryDark)
            .frame(width: 40, height: 40)
            .background(AppTheme.warmAccent, in: Circle())
            .overlay(Circle().strokeBorder(AppTheme.lightNeutral.opacity(0.35), lineWidth: 1))
            .shadow(color: AppTheme.glowAccent, radius: 6, y: 2)
    }
}

extension View {
    func appPanel(cornerRadius: CGFloat = AppTheme.cardCornerRadius) -> some View {
        modifier(AppPanelCard(cornerRadius: cornerRadius))
    }

    func glassCard(cornerRadius: CGFloat = AppTheme.cardCornerRadius) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius))
    }

    func classicCard(cornerRadius: CGFloat = AppTheme.cardCornerRadius) -> some View {
        modifier(ClassicCard(cornerRadius: cornerRadius))
    }

    func appIconButton(prominent: Bool = false, tint: Color = AppTheme.lightNeutral) -> some View {
        modifier(AppIconButton(prominent: prominent, tint: tint))
    }

    func tintedIcon(_ tint: Color = AppTheme.lightNeutral) -> some View {
        modifier(TintedIconButton(tint: tint))
    }

    func tintedIconGradient() -> some View {
        modifier(TintedIconGradientButton())
    }

    /// Plain symbol for a `Menu` label inside `.toolbar` (do not use `tintedIcon` / `appIconButton` there).
    func appToolbarMenuLabel() -> some View {
        font(.system(size: 17, weight: .semibold))
            .foregroundStyle(AppTheme.lightNeutral)
    }

    /// Standard navigation bar styling for list / form screens.
    func appNavigationChrome() -> some View {
        toolbarBackground(AppTheme.background.opacity(0.92), for: .navigationBar)
            .toolbarBackgroundVisibility(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
    }

    /// Sheet / full-screen cover background tint.
    func appSheetBackground() -> some View {
        presentationBackground(AppTheme.background)
    }

    /// Use on toolbar `Button`s so iOS does not draw a filled capsule behind the label.
    func appToolbarButtonStyle() -> some View {
        buttonStyle(.plain)
    }
}

// MARK: - Tab Screen Header

private struct PresentAccountKey: EnvironmentKey {
    static let defaultValue: (() -> Void)? = nil
}

extension EnvironmentValues {
    var presentAccount: (() -> Void)? {
        get { self[PresentAccountKey.self] }
        set { self[PresentAccountKey.self] = newValue }
    }
}

/// Custom top bar for main tabs — avoids UIKit toolbar button chrome (identical on every tab).
struct AppScreenHeaderMenuItem: Identifiable {
    let id = UUID()
    let title: String
    var systemImage: String? = nil
    let action: () -> Void
}

struct AppScreenHeader: View {
    let title: String
    var leading: AppScreenHeaderAction?
    var trailing: AppScreenHeaderAction?
    var trailingMenu: [AppScreenHeaderMenuItem]? = nil
    var profileInitial: String? = nil
    var onProfileTap: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 0) {
            headerSlot(leading, alignment: .leading)
            Spacer(minLength: 8)
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(AppTheme.lightNeutral)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            Spacer(minLength: 8)
            trailingSlot(alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background {
            AppTopBarBackground()
                .ignoresSafeArea(edges: .top)
        }
    }

    @ViewBuilder
    private func headerSlot(_ action: AppScreenHeaderAction?, alignment: Alignment) -> some View {
        if let action {
            Button(action: action.handler) {
                Image(systemName: action.systemImage)
                    .font(.system(size: action.fontSize, weight: .medium))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(action.tint)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(action.accessibilityLabel)
            .frame(width: 44, alignment: alignment)
        } else {
            Color.clear.frame(width: 44, height: 44)
        }
    }

    @ViewBuilder
    private func trailingSlot(alignment: Alignment) -> some View {
        HStack(spacing: 0) {
            if let profileInitial, let onProfileTap {
                Button(action: onProfileTap) {
                    Text(profileInitial)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.primaryText)
                        .frame(width: 32, height: 32)
                        .background(AppTheme.glowCyan.opacity(0.2))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Account")
            }

            if let trailingMenu, !trailingMenu.isEmpty {
                Menu {
                    ForEach(trailingMenu) { item in
                        Button(action: item.action) {
                            if let icon = item.systemImage {
                                Label(item.title, systemImage: icon)
                            } else {
                                Text(item.title)
                            }
                        }
                    }
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 22, weight: .medium))
                        .symbolRenderingMode(.monochrome)
                        .foregroundStyle(AppTheme.warmAccent)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Scan a room")
            } else {
                headerSlot(trailing, alignment: alignment)
            }
        }
        .frame(minWidth: 44, alignment: alignment)
    }
}

struct AppScreenHeaderAction {
    let systemImage: String
    let tint: Color
    let fontSize: CGFloat
    let accessibilityLabel: String
    let handler: () -> Void

    static func leading(
        _ systemImage: String,
        accessibilityLabel: String,
        handler: @escaping () -> Void
    ) -> AppScreenHeaderAction {
        AppScreenHeaderAction(
            systemImage: systemImage,
            tint: AppTheme.lightNeutral,
            fontSize: 18,
            accessibilityLabel: accessibilityLabel,
            handler: handler
        )
    }

    static func add(accessibilityLabel: String, handler: @escaping () -> Void) -> AppScreenHeaderAction {
        AppScreenHeaderAction(
            systemImage: "plus.circle",
            tint: AppTheme.warmAccent,
            fontSize: 22,
            accessibilityLabel: accessibilityLabel,
            handler: handler
        )
    }
}

// MARK: - Toolbar Icons (push / sheet screens)

/// Flat leading navigation-bar icon (history, SHARP, etc.).
struct AppToolbarLeadingIcon: View {
    let systemName: String

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 18, weight: .regular))
            .symbolRenderingMode(.monochrome)
            .foregroundStyle(AppTheme.lightNeutral)
    }
}

/// Flat trailing “add” icon — outline circle, matches tab header.
struct AppToolbarAddIcon: View {
    var body: some View {
        Image(systemName: "plus.circle")
            .font(.system(size: 22, weight: .regular))
            .symbolRenderingMode(.monochrome)
            .foregroundStyle(AppTheme.warmAccent)
    }
}

// MARK: - Status Chip

struct StatusChip: View {
    let label: String
    let color: Color

    var body: some View {
        Text(label)
            .font(.appCaption2)
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(color.opacity(0.28), lineWidth: 0.8))
    }
}

// MARK: - Section Header

struct ThemeSectionHeader: View {
    let title: String
    var icon: String? = nil

    var body: some View {
        HStack(spacing: 8) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.warmAccent)
            }
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppTheme.tertiaryText)
                .tracking(1.2)
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }
}

// MARK: - Empty State

struct AppEmptyState: View {
    let icon: String
    let title: String
    let message: String
    let ctaLabel: String
    let action: () -> Void
    /// When true, uses tighter padding for embedding in a scroll view (tab lists).
    var compact: Bool = false

    var body: some View {
        VStack(spacing: compact ? 16 : 20) {
            Image(systemName: icon)
                .font(.system(size: 48, weight: .thin))
                .foregroundStyle(AppTheme.tertiaryText)

            VStack(spacing: 6) {
                Text(title)
                    .font(.appTitle2)
                    .foregroundStyle(AppTheme.primaryText)
                Text(message)
                    .font(.appCallout)
                    .foregroundStyle(AppTheme.tertiaryText)
                    .multilineTextAlignment(.center)
            }

            Button(action: action) {
                Text(ctaLabel)
            }
            .buttonStyle(GradientButtonStyle())
            .padding(.top, 4)
        }
        .padding(compact ? 24 : 36)
    }
}

// MARK: - Animated Mesh Background (splash only)

struct AnimatedMeshBackground: View {
    @State private var animatePhase = false

    var body: some View {
        ZStack {
            AppTheme.primaryDark

            Circle()
                .fill(AppTheme.secondaryTint.opacity(0.22))
                .frame(width: 340, height: 340)
                .blur(radius: 100)
                .offset(x: animatePhase ? -60 : 60, y: animatePhase ? -120 : -80)

            Circle()
                .fill(AppTheme.warmAccent.opacity(0.14))
                .frame(width: 280, height: 280)
                .blur(radius: 90)
                .offset(x: animatePhase ? 80 : -40, y: animatePhase ? 180 : 120)

            Circle()
                .fill(AppTheme.lightNeutral.opacity(0.06))
                .frame(width: 200, height: 200)
                .blur(radius: 70)
                .offset(x: animatePhase ? -100 : 20, y: animatePhase ? 40 : -40)
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                animatePhase = true
            }
        }
    }
}
