//
//  LoginView.swift
//  ClaudeMeter
//
//  Copyright (c) 2026 puq.ai. All rights reserved.
//  Licensed under the MIT License. See LICENSE file.
//

import SwiftUI

/// Login view shown when no credentials are found.
/// Handles the OAuth PKCE flow: open browser → user copies code → paste → exchange.
struct LoginView: View {
    @ObservedObject var appState: AppState

    @State private var authCode: String = ""
    @State private var state: LoginState = .idle
    @State private var errorMessage: String?

    enum LoginState {
        case idle
        case waitingForCode
        case exchanging
        case error
    }

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            // Icon
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 40))
                .foregroundStyle(ColorTheme.accent)
                .symbolRenderingMode(.hierarchical)

            // Title
            Text("Sign in to Claude")
                .font(.headline)

            Text("Monitor your API usage limits")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Sign in button
            if state == .idle || state == .error {
                Button(action: openBrowser) {
                    Label("Sign in with Claude", systemImage: "safari")
                }
                .buttonStyle(.borderedProminent)
                .tint(ColorTheme.accent)
                .controlSize(.large)
            }

            // After browser opened: code entry
            if state == .waitingForCode || state == .error {
                VStack(spacing: 10) {
                    Divider()
                        .padding(.vertical, 4)

                    Text("After signing in, paste your code below:")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    TextField("Paste authorization code", text: $authCode)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .padding(.horizontal, 24)

                    Button("Continue") {
                        Task { await exchangeCode() }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(ColorTheme.accent)
                    .disabled(authCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }

            // Exchanging spinner
            if state == .exchanging {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Signing in...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Error message
            if let errorMessage, state == .error {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(ColorTheme.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Spacer()
        }
        .padding()
    }

    // MARK: - Actions

    private func openBrowser() {
        let url = appState.startOAuthLogin()
        NSWorkspace.shared.open(url)
        withAnimation {
            state = .waitingForCode
            errorMessage = nil
        }
    }

    private func exchangeCode() async {
        let code = authCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else { return }

        withAnimation { state = .exchanging }
        errorMessage = nil

        do {
            try await appState.completeOAuthLogin(code: code)
            // Success — AppState.refresh() will load data and clear the error,
            // causing PopoverView to switch away from LoginView automatically.
        } catch {
            withAnimation { state = .error }
            errorMessage = error.localizedDescription
        }
    }
}
