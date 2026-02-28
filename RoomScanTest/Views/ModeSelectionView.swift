//
//  ModeSelectionView.swift
//  RoomScanTest
//
//  Created by Mara Ielciu on 28.02.2026.
//

import SwiftUI

/// First screen the user sees — choose between Local mode (original) or Marketplace mode (Firebase).
struct ModeSelectionView: View {
    @Binding var selectedMode: AppMode?

    @State private var appear = false

    var body: some View {
        ZStack {
            AnimatedMeshBackground()

            VStack(spacing: 0) {
                Spacer()

                // ── Logo ──
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.glowCyan.opacity(0.12))
                            .frame(width: 140, height: 140)
                            .blur(radius: 30)

                        Image(systemName: "cube.transparent.fill")
                            .font(.system(size: 48, weight: .light))
                            .foregroundStyle(AppTheme.accentGradientInline)
                            .frame(width: 100, height: 100)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(
                                        LinearGradient(
                                            colors: [Color.white.opacity(0.25), Color.white.opacity(0.05)],
                                            startPoint: .topLeading, endPoint: .bottomTrailing
                                        ), lineWidth: 1
                                    )
                            )
                    }
                    .scaleEffect(appear ? 1.0 : 0.6)
                    .opacity(appear ? 1 : 0)

                    VStack(spacing: 8) {
                        Text("Room Designer")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundColor(.white)

                        Text("Choose how you'd like to get started")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(AppTheme.secondaryText)
                    }
                    .opacity(appear ? 1 : 0)
                }

                Spacer().frame(height: 48)

                // ── Mode Cards ──
                VStack(spacing: 16) {
                    // Local Mode
                    Button { selectedMode = .local } label: {
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(AppTheme.glowGreen.opacity(0.12))
                                    .frame(width: 50, height: 50)
                                Image(systemName: "iphone")
                                    .font(.system(size: 22))
                                    .foregroundStyle(AppTheme.glowGreen)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Local Mode")
                                    .font(.headline.weight(.semibold))
                                    .foregroundColor(.white)
                                Text("Everything stays on your device. No account needed.")
                                    .font(.caption)
                                    .foregroundColor(AppTheme.secondaryText)
                                    .lineLimit(2)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(AppTheme.tertiaryText)
                        }
                        .padding(16)
                        .glassCard(cornerRadius: AppTheme.cornerRadius)
                    }

                    // Marketplace Mode
                    Button { selectedMode = .marketplace } label: {
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(AppTheme.glowViolet.opacity(0.12))
                                    .frame(width: 50, height: 50)
                                Image(systemName: "globe")
                                    .font(.system(size: 22))
                                    .foregroundStyle(AppTheme.accentGradientInline)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Text("Marketplace")
                                        .font(.headline.weight(.semibold))
                                        .foregroundColor(.white)
                                    Text("NEW")
                                        .font(.system(size: 9, weight: .heavy))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(AppTheme.accentGradientInline)
                                        .clipShape(Capsule())
                                }
                                Text("Sign in, share 3D scans & browse community models.")
                                    .font(.caption)
                                    .foregroundColor(AppTheme.secondaryText)
                                    .lineLimit(2)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(AppTheme.tertiaryText)
                        }
                        .padding(16)
                        .glassCard(cornerRadius: AppTheme.cornerRadius)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                                .stroke(AppTheme.accentGradientInline, lineWidth: 1)
                        )
                    }
                }
                .padding(.horizontal, 24)
                .opacity(appear ? 1 : 0)
                .offset(y: appear ? 0 : 40)

                Spacer()

                Text("You can switch modes at any time")
                    .font(.caption2)
                    .foregroundColor(AppTheme.tertiaryText)
                    .padding(.bottom, 30)
                    .opacity(appear ? 1 : 0)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.7).delay(0.1)) {
                appear = true
            }
        }
    }
}
