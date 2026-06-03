//
//  AuthenticationView.swift
//  RoomScanTest
//

import SwiftUI

struct AuthenticationView: View {
    @ObservedObject var authManager: AuthenticationManager
    @State private var mode: AuthMode = .signIn
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""

    enum AuthMode: String, CaseIterable {
        case signIn = "Sign In"
        case register = "Register"
    }

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 28) {
                    VStack(spacing: 10) {
                        Image(systemName: "cube.transparent.fill")
                            .font(.system(size: 44, weight: .light))
                            .foregroundStyle(AppTheme.accentGradient)
                        Text("RoomScan")
                            .font(.largeTitle.weight(.bold))
                            .foregroundStyle(AppTheme.primaryText)
                        Text("Sign in to access your rooms, projects, and scans")
                            .font(.subheadline)
                            .foregroundColor(AppTheme.secondaryText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    .padding(.top, 40)

                    Picker("Mode", selection: $mode) {
                        ForEach(AuthMode.allCases, id: \.self) { m in
                            Text(m.rawValue).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 24)

                    VStack(spacing: 14) {
                        if mode == .register {
                            authField("Full name", text: $name, contentType: .name)
                        }
                        authField("Email", text: $email, contentType: .emailAddress)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                        authField("Password", text: $password, contentType: .password, secure: true)
                        if mode == .register {
                            authField("Confirm password", text: $confirmPassword, contentType: .password, secure: true)
                        }
                    }
                    .padding(.horizontal, 24)

                    if let error = authManager.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red.opacity(0.9))
                            .padding(.horizontal, 24)
                    }

                    Button(action: submitPrimary) {
                        Group {
                            if authManager.isLoading {
                                ProgressView().tint(AppTheme.primaryDark)
                            } else {
                                Text(mode == .signIn ? "Sign In" : "Create Account")
                                    .font(.headline)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.warmAccent)
                    .disabled(authManager.isLoading || !canSubmit)
                    .padding(.horizontal, 24)

                    dividerLabel("or")

                    Button(action: {
                        Task { await authManager.signInWithGoogle() }
                    }) {
                        HStack(spacing: 10) {
                            Image(systemName: "g.circle.fill")
                                .font(.title3)
                            Text("Continue with Google")
                                .font(.subheadline.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                    }
                    .foregroundStyle(AppTheme.primaryText)
                    .background(AppTheme.surfacePrimary)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius)
                            .stroke(AppTheme.warmAccent.opacity(0.25), lineWidth: 1)
                    )
                    .disabled(authManager.isLoading)
                    .padding(.horizontal, 24)

                    if !GoogleSignInService.isAvailable {
                        Text("Add the GoogleSignIn package and GIDClientID in Info.plist (see AUTH_SETUP.md).")
                            .font(.caption2)
                            .foregroundColor(AppTheme.secondaryText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }

                    Spacer(minLength: 40)
                }
            }
        }
    }

    private var canSubmit: Bool {
        guard !email.trimmingCharacters(in: .whitespaces).isEmpty, password.count >= 8 else { return false }
        if mode == .register {
            return !name.trimmingCharacters(in: .whitespaces).isEmpty && password == confirmPassword
        }
        return true
    }

    private func submitPrimary() {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            if mode == .signIn {
                await authManager.signIn(email: trimmedEmail, password: password)
            } else {
                guard password == confirmPassword else {
                    authManager.showError("Passwords do not match.")
                    return
                }
                await authManager.register(
                    name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                    email: trimmedEmail,
                    password: password
                )
            }
        }
    }

    @ViewBuilder
    private func authField(
        _ placeholder: String,
        text: Binding<String>,
        contentType: UITextContentType,
        secure: Bool = false
    ) -> some View {
        Group {
            if secure {
                SecureField(placeholder, text: text)
            } else {
                TextField(placeholder, text: text)
            }
        }
        .textContentType(contentType)
        .padding(14)
        .background(AppTheme.surfacePrimary)
        .foregroundStyle(AppTheme.primaryText)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius)
                .stroke(AppTheme.warmAccent.opacity(0.2), lineWidth: 1)
        )
    }

    private func dividerLabel(_ text: String) -> some View {
        HStack {
            Rectangle().fill(AppTheme.warmAccent.opacity(0.2)).frame(height: 1)
            Text(text).font(.caption).foregroundColor(AppTheme.secondaryText)
            Rectangle().fill(AppTheme.warmAccent.opacity(0.2)).frame(height: 1)
        }
        .padding(.horizontal, 24)
    }
}
