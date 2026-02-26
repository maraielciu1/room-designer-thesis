//
//  LandingView.swift
//  RoomScanTest
//
//  Created by Mara Ielciu on 16.02.2026.
//

import SwiftUI

struct LandingView: View {
    @EnvironmentObject var userManager: UserManager
    @State private var showUserSelection = false
    @State private var logoScale: CGFloat = 0.6
    @State private var logoOpacity: Double = 0
    @State private var buttonsOffset: CGFloat = 40
    @State private var buttonsOpacity: Double = 0

    var body: some View {
        ZStack {
            // Animated dark mesh background
            AnimatedMeshBackground()

            VStack(spacing: 0) {
                Spacer()

                // ── Logo & Title ──
                VStack(spacing: 16) {
                    ZStack {
                        // Outer glow ring
                        Circle()
                            .fill(AppTheme.glowCyan.opacity(0.12))
                            .frame(width: 140, height: 140)
                            .blur(radius: 30)

                        // Glass circle with icon
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
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)

                    VStack(spacing: 8) {
                        Text("Room Designer")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundColor(.white)

                        Text("Transform your space with AR")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(AppTheme.secondaryText)
                    }
                    .opacity(logoOpacity)
                }

                Spacer().frame(height: 48)

                // ── Current User Badge ──
                if let user = userManager.currentUser {
                    Button(action: { showUserSelection = true }) {
                        HStack(spacing: 10) {
                            Image(systemName: "person.crop.circle.fill")
                                .foregroundStyle(AppTheme.accentGradientInline)
                            Text(user.name)
                                .foregroundColor(.white.opacity(0.9))
                            Spacer()
                            Text("Switch")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(AppTheme.glowCyan)
                        }
                        .font(.subheadline)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .glassCard(cornerRadius: 14)
                    }
                    .padding(.horizontal, 36)
                    .opacity(buttonsOpacity)
                    .offset(y: buttonsOffset)
                }

                Spacer()

                // ── Navigation Buttons ──
                VStack(spacing: 14) {
                    NavigationLink(destination: RoomListView()) {
                        HStack(spacing: 12) {
                            Image(systemName: "house.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(AppTheme.accentGradientInline)
                                .frame(width: 40, height: 40)
                                .background(AppTheme.glowCyan.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 10))

                            VStack(alignment: .leading, spacing: 2) {
                                Text("My Rooms")
                                    .font(.headline.weight(.semibold))
                                    .foregroundColor(.white)
                                Text("View & edit scanned rooms")
                                    .font(.caption)
                                    .foregroundColor(AppTheme.secondaryText)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(AppTheme.tertiaryText)
                        }
                        .padding(16)
                        .glassCard(cornerRadius: AppTheme.cornerRadius)
                    }

                    NavigationLink(destination: FurnitureLibraryView()) {
                        HStack(spacing: 12) {
                            Image(systemName: "cube.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(AppTheme.accentGradientInline)
                                .frame(width: 40, height: 40)
                                .background(AppTheme.glowViolet.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 10))

                            VStack(alignment: .leading, spacing: 2) {
                                Text("My Furniture")
                                    .font(.headline.weight(.semibold))
                                    .foregroundColor(.white)
                                Text("Scanned models & built-in library")
                                    .font(.caption)
                                    .foregroundColor(AppTheme.secondaryText)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(AppTheme.tertiaryText)
                        }
                        .padding(16)
                        .glassCard(cornerRadius: AppTheme.cornerRadius)
                    }
                }
                .padding(.horizontal, 24)
                .opacity(buttonsOpacity)
                .offset(y: buttonsOffset)

                Spacer().frame(height: 50)
            }
        }
        .sheet(isPresented: $showUserSelection) {
            UserSelectionView()
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.7).delay(0.1)) {
                logoScale = 1.0
                logoOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.6).delay(0.35)) {
                buttonsOffset = 0
                buttonsOpacity = 1.0
            }
        }
    }
}

#Preview {
    NavigationView {
        LandingView()
            .environmentObject(UserManager())
    }
}
