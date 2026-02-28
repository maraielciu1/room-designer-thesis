//
//  MarketplaceAuthView.swift
//  RoomScanTest
//
//  Created by Mara Ielciu on 28.02.2026.
//

import SwiftUI

/// Sign-in / Sign-up view for the Marketplace mode.
struct MarketplaceAuthView: View {
    @EnvironmentObject var authManager: FirebaseAuthManager
    @EnvironmentObject var marketplaceManager: MarketplaceManager

    @State private var isSignUp = false
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var showForgotPassword = false
    @State private var forgotEmail = ""
    @State private var forgotSent = false

    var body: some View {
        ZStack {
            AnimatedMeshBackground()

            ScrollView {
                VStack(spacing: 28) {
                    Spacer().frame(height: 40)

                    // ── Header ──
                    VStack(spacing: 12) {
                        Image(systemName: "globe")
                            .font(.system(size: 44, weight: .light))
                            .foregroundStyle(AppTheme.accentGradientInline)
                            .frame(width: 80, height: 80)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1))

                        Text(isSignUp ? "Create Account" : "Welcome Back")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.white)

                        Text(isSignUp
                             ? "Join the community marketplace"
                             : "Sign in to browse & share models")
                            .font(.subheadline)
                            .foregroundColor(AppTheme.secondaryText)
                    }

                    // ── Form ──
                    VStack(spacing: 16) {
                        if isSignUp {
                            AuthTextField(
                                icon: "person.fill",
                                placeholder: "Display Name",
                                text: $displayName
                            )
                        }

                        AuthTextField(
                            icon: "envelope.fill",
                            placeholder: "Email",
                            text: $email,
                            keyboardType: .emailAddress,
                            autocap: .never
                        )

                        AuthTextField(
                            icon: "lock.fill",
                            placeholder: "Password",
                            text: $password,
                            isSecure: true
                        )

                        if !isSignUp {
                            HStack {
                                Spacer()
                                Button("Forgot password?") {
                                    forgotEmail = email
                                    showForgotPassword = true
                                }
                                .font(.caption.weight(.medium))
                                .foregroundColor(AppTheme.glowCyan)
                            }
                        }
                    }
                    .padding(.horizontal, 24)

                    // ── Error ──
                    if let err = authManager.errorMessage {
                        Text(err)
                            .font(.caption)
                            .foregroundColor(AppTheme.glowRed)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }

                    // ── Action Button ──
                    Button {
                        Task {
                            if isSignUp {
                                await authManager.signUp(email: email, password: password, displayName: displayName)
                            } else {
                                await authManager.signIn(email: email, password: password)
                            }
                            // Ensure Firestore profile exists
                            if let user = authManager.marketplaceUser {
                                await marketplaceManager.ensureUserProfile(user)
                            }
                        }
                    } label: {
                        Group {
                            if authManager.isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text(isSignUp ? "Create Account" : "Sign In")
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(GradientButtonStyle())
                    .disabled(authManager.isLoading || !formIsValid)
                    .opacity(formIsValid ? 1.0 : 0.5)
                    .padding(.horizontal, 24)

                    // ── Toggle Sign In / Sign Up ──
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            isSignUp.toggle()
                            authManager.errorMessage = nil
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(isSignUp ? "Already have an account?" : "Don't have an account?")
                                .foregroundColor(AppTheme.secondaryText)
                            Text(isSignUp ? "Sign In" : "Sign Up")
                                .foregroundColor(AppTheme.glowCyan)
                                .fontWeight(.semibold)
                        }
                        .font(.subheadline)
                    }

                    Spacer()
                }
            }
        }
        .sheet(isPresented: $showForgotPassword) {
            forgotPasswordSheet
        }
    }

    // MARK: - Validation

    private var formIsValid: Bool {
        let validEmail = email.contains("@") && email.contains(".")
        let validPassword = password.count >= 6
        if isSignUp {
            return validEmail && validPassword && !displayName.trimmingCharacters(in: .whitespaces).isEmpty
        }
        return validEmail && validPassword
    }

    // MARK: - Forgot Password Sheet

    private var forgotPasswordSheet: some View {
        ZStack {
            Color(hex: 0x0B0D17).ignoresSafeArea()

            VStack(spacing: 24) {
                Text("Reset Password")
                    .font(.title2.weight(.bold))
                    .foregroundColor(.white)

                if forgotSent {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(AppTheme.glowGreen)
                        Text("Reset email sent!")
                            .foregroundColor(.white)
                        Text("Check your inbox for a password reset link.")
                            .font(.caption)
                            .foregroundColor(AppTheme.secondaryText)
                    }
                } else {
                    AuthTextField(
                        icon: "envelope.fill",
                        placeholder: "Your email address",
                        text: $forgotEmail,
                        keyboardType: .emailAddress,
                        autocap: .never
                    )
                    .padding(.horizontal, 24)

                    Button("Send Reset Link") {
                        Task {
                            await authManager.resetPassword(email: forgotEmail)
                            forgotSent = true
                        }
                    }
                    .buttonStyle(GradientButtonStyle())
                }

                Button("Close") {
                    showForgotPassword = false
                    forgotSent = false
                }
                .buttonStyle(GhostButtonStyle())
            }
            .padding()
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Styled Text Field

struct AuthTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var autocap: TextInputAutocapitalization = .words
    var isSecure: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(AppTheme.secondaryText)
                .frame(width: 20)

            if isSecure {
                SecureField(placeholder, text: $text)
                    .foregroundColor(.white)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } else {
                TextField(placeholder, text: $text)
                    .foregroundColor(.white)
                    .keyboardType(keyboardType)
                    .textInputAutocapitalization(autocap)
                    .autocorrectionDisabled()
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.06))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }
}
