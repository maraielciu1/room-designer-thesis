//
//  AppTheme.swift
//  RoomScanTest
//
//  Centralised design tokens and reusable modifiers for a modern,
//  sleek, dark-mode-first UI.
//

import SwiftUI

// MARK: - Colour Palette

enum AppTheme {

    // Accent gradient
    static let accentGradient = LinearGradient(
        colors: [Color("AccentStart"), Color("AccentEnd")],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    // Fallback inline gradient (used before asset catalog colours are set)
    static let accentGradientInline = LinearGradient(
        colors: [Color(hex: 0x6C63FF), Color(hex: 0x00D4FF)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    // Mesh background gradient (dark scene)
    static let backgroundGradient = LinearGradient(
        colors: [Color(hex: 0x0B0D17), Color(hex: 0x111827), Color(hex: 0x0F172A)],
        startPoint: .top, endPoint: .bottom
    )

    // Card / surface fill
    static let surfaceGradient = LinearGradient(
        colors: [Color.white.opacity(0.08), Color.white.opacity(0.03)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    // Subtle glow for feature cards
    static let glowCyan   = Color(hex: 0x00D4FF)
    static let glowViolet = Color(hex: 0x6C63FF)
    static let glowGreen  = Color(hex: 0x34D399)
    static let glowOrange = Color(hex: 0xFB923C)
    static let glowRed    = Color(hex: 0xEF4444)

    // Text
    static let primaryText   = Color.white
    static let secondaryText = Color.white.opacity(0.6)
    static let tertiaryText  = Color.white.opacity(0.4)

    // Fixed sizes
    static let cornerRadius: CGFloat = 18
    static let cardCornerRadius: CGFloat = 16
    static let buttonCornerRadius: CGFloat = 14
}

// MARK: - Hex Colour Convenience

extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red:   Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8)  & 0xFF) / 255,
            blue:  Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

// MARK: - Reusable View Modifiers

/// Glass-morphism card surface.
struct GlassCard: ViewModifier {
    var cornerRadius: CGFloat = AppTheme.cardCornerRadius

    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
    }
}

/// Gradient-filled pill button.
struct GradientButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 28)
            .padding(.vertical, 14)
            .background(
                AppTheme.accentGradientInline
                    .opacity(configuration.isPressed ? 0.75 : 1.0)
            )
            .clipShape(Capsule())
            .shadow(color: AppTheme.glowCyan.opacity(0.35),
                    radius: configuration.isPressed ? 4 : 10, y: 4)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// Secondary ghost button with border.
struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundColor(.white.opacity(0.85))
            .padding(.horizontal, 22)
            .padding(.vertical, 11)
            .background(Color.white.opacity(configuration.isPressed ? 0.12 : 0.06))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// Small tinted icon button (for toolbars, etc.).
struct TintedIconButton: ViewModifier {
    var tint: Color = AppTheme.glowCyan

    func body(content: Content) -> some View {
        content
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(tint)
            .padding(10)
            .background(.ultraThinMaterial)
            .clipShape(Circle())
            .overlay(Circle().stroke(tint.opacity(0.25), lineWidth: 1))
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = AppTheme.cardCornerRadius) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius))
    }

    func tintedIcon(_ tint: Color = AppTheme.glowCyan) -> some View {
        modifier(TintedIconButton(tint: tint))
    }
}

// MARK: - Animated Gradient Background

struct AnimatedMeshBackground: View {
    @State private var animatePhase = false

    var body: some View {
        ZStack {
            // Base
            Color(hex: 0x0B0D17)

            // Animated blobs
            Circle()
                .fill(AppTheme.glowViolet.opacity(0.18))
                .frame(width: 340, height: 340)
                .blur(radius: 100)
                .offset(x: animatePhase ? -60 : 60, y: animatePhase ? -120 : -80)

            Circle()
                .fill(AppTheme.glowCyan.opacity(0.12))
                .frame(width: 280, height: 280)
                .blur(radius: 90)
                .offset(x: animatePhase ? 80 : -40, y: animatePhase ? 180 : 120)

            Circle()
                .fill(Color(hex: 0x3B82F6).opacity(0.10))
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

// MARK: - Section Header

struct ThemeSectionHeader: View {
    let title: String
    var icon: String? = nil

    var body: some View {
        HStack(spacing: 8) {
            if let icon {
                Image(systemName: icon)
                    .foregroundStyle(AppTheme.accentGradientInline)
                    .font(.subheadline.weight(.semibold))
            }
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(AppTheme.secondaryText)
                .textCase(.uppercase)
                .tracking(0.8)
            Spacer()
        }
    }
}
