// AppTheme.swift
// RoomScanTest
//
// Centralised design tokens — classic, timeless, modern.
// Single indigo accent. Opaque surfaces. Restrained palette.

import SwiftUI

// MARK: - Colour Palette

enum AppTheme {

    // ── Backgrounds ──────────────────────────────────────────────────────────
    static let background          = Color(hex: 0x0A0A0F)   // near-black
    static let surfacePrimary      = Color(hex: 0x141418)   // card base
    static let surfaceSecondary    = Color(hex: 0x1C1C24)   // elevated card
    static let surfaceTertiary     = Color(hex: 0x25252F)   // chip / divider

    // ── Single accent: indigo ─────────────────────────────────────────────────
    static let accent              = Color(hex: 0x6366F1)   // indigo-500
    static let accentLight         = Color(hex: 0x818CF8)   // indigo-400
    static let accentMuted         = Color(hex: 0x6366F1, alpha: 0.15)

    static let accentGradient = LinearGradient(
        colors: [Color(hex: 0x6366F1), Color(hex: 0x8B5CF6)],
        startPoint: .topLeading, endPoint: .bottomTrailing)

    // Legacy alias so existing call-sites compile unchanged
    static let accentGradientInline = accentGradient
    static let glowBlue   = accent
    static let glowCyan   = accentLight
    static let glowViolet = accent

    // ── Status ────────────────────────────────────────────────────────────────
    static let glowGreen  = Color(hex: 0x22C55E)
    static let glowOrange = Color(hex: 0xF59E0B)
    static let glowRed    = Color(hex: 0xEF4444)

    // ── Text ──────────────────────────────────────────────────────────────────
    static let primaryText   = Color.white
    static let secondaryText = Color.white.opacity(0.60)
    static let tertiaryText  = Color.white.opacity(0.35)

    // ── Glow ──────────────────────────────────────────────────────────────────
    static let glowAccent = Color(hex: 0x6366F1, alpha: 0.28)

    // ── Tab bar ───────────────────────────────────────────────────────────────
    static let tabBarBackground     = Color(hex: 0x18181F)
    static let tabBarItemInactive   = Color.white.opacity(0.40)
    static let tabBarItemActive     = Color.white
    static let tabBarPill           = Color.white.opacity(0.10)

    // ── Sizes ─────────────────────────────────────────────────────────────────
    static let cornerRadius:       CGFloat = 18
    static let cardCornerRadius:   CGFloat = 16
    static let buttonCornerRadius: CGFloat = 14

    // ── Page background gradient (static — no animation outside splash) ───────
    static let pageBackground = LinearGradient(
        colors: [Color(hex: 0x0A0A0F), Color(hex: 0x0F0F18)],
        startPoint: .top, endPoint: .bottom)
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

// MARK: - Card Surface Modifier (opaque, clean edge)

struct ClassicCard: ViewModifier {
    var cornerRadius: CGFloat = AppTheme.cardCornerRadius

    func body(content: Content) -> some View {
        content
            .background(AppTheme.surfacePrimary)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.07), lineWidth: 1)
            )
    }
}

/// Legacy glass card — now forwards to ClassicCard for visual consistency.
struct GlassCard: ViewModifier {
    var cornerRadius: CGFloat = AppTheme.cardCornerRadius

    func body(content: Content) -> some View {
        content
            .modifier(ClassicCard(cornerRadius: cornerRadius))
    }
}

// MARK: - Button Styles

/// Primary gradient pill — one per screen.
struct GradientButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.appHeadline)
            .foregroundColor(.white)
            .padding(.horizontal, 28)
            .padding(.vertical, 15)
            .background(
                AppTheme.accentGradient
                    .opacity(configuration.isPressed ? 0.78 : 1.0)
            )
            .clipShape(Capsule())
            .shadow(color: AppTheme.glowAccent,
                    radius: configuration.isPressed ? 4 : 12, y: 4)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// Secondary ghost pill — for less important actions.
struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.appCallout.weight(.semibold))
            .foregroundColor(AppTheme.secondaryText)
            .padding(.horizontal, 22)
            .padding(.vertical, 12)
            .background(
                AppTheme.surfaceTertiary
                    .opacity(configuration.isPressed ? 0.7 : 1.0)
            )
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.10), lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Icon Button Modifiers

struct TintedIconButton: ViewModifier {
    var tint: Color = AppTheme.accentLight

    func body(content: Content) -> some View {
        content
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(tint)
            .frame(width: 38, height: 38)
            .background(AppTheme.surfaceSecondary, in: Circle())
            .overlay(Circle().strokeBorder(tint.opacity(0.20), lineWidth: 1))
    }
}

struct TintedIconGradientButton: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 16, weight: .bold))
            .foregroundColor(.white)
            .frame(width: 38, height: 38)
            .background(AppTheme.accentGradient, in: Circle())
            .overlay(Circle().strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
            .shadow(color: AppTheme.glowAccent, radius: 6, y: 2)
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = AppTheme.cardCornerRadius) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius))
    }

    func classicCard(cornerRadius: CGFloat = AppTheme.cardCornerRadius) -> some View {
        modifier(ClassicCard(cornerRadius: cornerRadius))
    }

    func tintedIcon(_ tint: Color = AppTheme.accentLight) -> some View {
        modifier(TintedIconButton(tint: tint))
    }

    func tintedIconGradient() -> some View {
        modifier(TintedIconGradientButton())
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
                    .foregroundStyle(AppTheme.accentLight)
            }
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(AppTheme.tertiaryText)
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

    var body: some View {
        VStack(spacing: 20) {
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
        .padding(36)
    }
}

// MARK: - Animated Mesh Background (splash only)

struct AnimatedMeshBackground: View {
    @State private var animatePhase = false

    var body: some View {
        ZStack {
            Color(hex: 0x0A0A0F)

            Circle()
                .fill(AppTheme.accent.opacity(0.13))
                .frame(width: 340, height: 340)
                .blur(radius: 100)
                .offset(x: animatePhase ? -60 : 60, y: animatePhase ? -120 : -80)

            Circle()
                .fill(AppTheme.accentLight.opacity(0.10))
                .frame(width: 280, height: 280)
                .blur(radius: 90)
                .offset(x: animatePhase ? 80 : -40, y: animatePhase ? 180 : 120)

            Circle()
                .fill(Color(hex: 0x8B5CF6).opacity(0.09))
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
