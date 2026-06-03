// AppSplashView.swift
// RoomScanTest
//
// Animated splash shown on every cold launch.
// Animated mesh background kept here only.

import SwiftUI

struct AppSplashView: View {
    var onFinish: () -> Void

    @State private var logoScale:    CGFloat = 0.4
    @State private var logoOpacity:  Double  = 0
    @State private var ring1Scale:   CGFloat = 0.6
    @State private var ring2Scale:   CGFloat = 0.6
    @State private var ringsOpacity: Double  = 0
    @State private var glowPulse             = false
    @State private var textOpacity:  Double  = 0
    @State private var textOffset:   CGFloat = 24
    @State private var buttonOpacity: Double = 0
    @State private var buttonOffset:  CGFloat = 28

    var body: some View {
        ZStack {
            // Animated mesh lives here only
            AnimatedMeshBackground()

            VStack(spacing: 0) {
                Spacer()

                // ── Logo ─────────────────────────────────────────────────────
                ZStack {
                    // Outer ring
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    AppTheme.accent.opacity(glowPulse ? 0.32 : 0.08),
                                    AppTheme.accentLight.opacity(glowPulse ? 0.16 : 0.03)
                                ],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                        .frame(width: 192, height: 192)
                        .scaleEffect(ring1Scale)

                    // Inner ring
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(glowPulse ? 0.14 : 0.05),
                                    AppTheme.accent.opacity(glowPulse ? 0.22 : 0.06)
                                ],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                        .frame(width: 144, height: 144)
                        .scaleEffect(ring2Scale)

                    // Glow blob
                    Circle()
                        .fill(AppTheme.accent.opacity(0.18))
                        .frame(width: 110, height: 110)
                        .blur(radius: 28)
                        .scaleEffect(glowPulse ? 1.18 : 0.88)

                    // Icon badge
                    Image(systemName: "cube.transparent.fill")
                        .font(.system(size: 50, weight: .light))
                        .foregroundStyle(AppTheme.accentGradient)
                        .frame(width: 104, height: 104)
                        .background(AppTheme.surfacePrimary)
                        .clipShape(Circle())
                        .overlay(
                            Circle().strokeBorder(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.25), AppTheme.lightNeutral.opacity(0.06)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing),
                                lineWidth: 1)
                        )
                        .shadow(color: AppTheme.glowAccent, radius: 24, y: 8)
                }
                .opacity(ringsOpacity)
                .scaleEffect(logoScale)
                .opacity(logoOpacity)

                Spacer().frame(height: 36)

                // ── App name + tagline ────────────────────────────────────────
                VStack(spacing: 10) {
                    Text("Room Designer")
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.primaryText)

                    Text("Design your space, from anywhere")
                        .font(.system(size: 16, weight: .regular, design: .rounded))
                        .foregroundColor(AppTheme.secondaryText)
                        .multilineTextAlignment(.center)
                }
                .opacity(textOpacity)
                .offset(y: textOffset)

                Spacer()

                // ── CTA ───────────────────────────────────────────────────────
                Button(action: onFinish) {
                    HStack(spacing: 10) {
                        Text("Get Started")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 15, weight: .semibold))
                    }
                }
                .buttonStyle(GradientButtonStyle())
                .opacity(buttonOpacity)
                .offset(y: buttonOffset)

                Spacer().frame(height: 56)
            }
            .padding(.horizontal, 32)
        }
        .onAppear { runEntrance() }
    }

    private func runEntrance() {
        withAnimation(.spring(response: 0.75, dampingFraction: 0.62).delay(0.08)) {
            logoScale    = 1.0; logoOpacity  = 1.0
            ring1Scale   = 1.0; ring2Scale   = 1.0; ringsOpacity = 1.0
        }
        withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true).delay(0.5)) {
            glowPulse = true
        }
        withAnimation(.easeOut(duration: 0.52).delay(0.45)) {
            textOpacity = 1.0; textOffset = 0
        }
        withAnimation(.easeOut(duration: 0.48).delay(0.75)) {
            buttonOpacity = 1.0; buttonOffset = 0
        }
    }
}

#Preview {
    AppSplashView(onFinish: {})
        .preferredColorScheme(.dark)
}
