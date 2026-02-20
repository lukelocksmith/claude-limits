//
//  GeneralSettingsView.swift
//  Claude Limits
//
//  Copyright (c) 2026 puq.ai. All rights reserved.
//  Licensed under the MIT License. See LICENSE file.
//

import SwiftUI
import ServiceManagement

// MARK: - General Settings
struct GeneralSettingsView: View {
    @ObservedObject var appState: AppState
    @State private var launchAtLoginError: String?

    var body: some View {
        SettingsTabContainer {
            Form {
                Section {
                    Toggle("Launch at Login", isOn: Binding(
                        get: { appState.settings.launchAtLogin },
                        set: { newValue in
                            appState.settings.launchAtLogin = newValue
                            toggleLaunchAtLogin(newValue)
                        }
                    ))
                    .help("Automatically start Claude Limits when you log in.")
                    .accessibilityLabel("Launch at Login")
                    .accessibilityHint("When enabled, Claude Limits will start automatically when you log in")

                    if let error = launchAtLoginError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(ColorTheme.red)
                            .accessibilityLabel("Error: \(error)")
                    }

                    Toggle("Show in Dock", isOn: Binding(
                        get: { appState.settings.showInDock },
                        set: { newValue in
                            appState.settings.showInDock = newValue
                            updateDockVisibility(newValue)
                        }
                    ))
                    .help("Show Claude Limits icon in the Dock.")
                    .accessibilityLabel("Show in Dock")
                    .accessibilityHint("When enabled, Claude Limits will appear in the Dock")

                    Picker("Refresh Interval", selection: $appState.settings.refreshInterval) {
                        Text("30 Seconds").tag(30)
                        Text("1 Minute").tag(60)
                        Text("2 Minutes").tag(120)
                        Text("5 Minutes").tag(300)
                    }
                    .accessibilityLabel("Refresh Interval")
                    .accessibilityHint("Choose how often to update usage data")
                }

                Section(header: Text("Display")) {
                    Toggle("Show Sonnet Limit", isOn: $appState.settings.showSonnetLimit)
                        .help("Display Sonnet model weekly usage limit.")
                        .accessibilityLabel("Show Sonnet Limit")
                        .accessibilityHint("When enabled, shows the Sonnet model usage limit")

                    Toggle("Show Opus Limit", isOn: $appState.settings.showOpusLimit)
                        .help("Display Opus model usage limit in the usage view.")
                        .accessibilityLabel("Show Opus Limit")
                        .accessibilityHint("When enabled, shows the Opus model usage limit")

                    Toggle("Show Extra Usage", isOn: $appState.settings.showExtraUsage)
                        .help("Display extra usage spending and monthly limit.")
                        .accessibilityLabel("Show Extra Usage")
                        .accessibilityHint("When enabled, shows extra usage billing information")
                }

                Section(header: Text("Account")) {
                    Button(role: .destructive) {
                        appState.logout()
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                    .help("Sign out and remove stored credentials.")
                    .accessibilityLabel("Sign Out")
                    .accessibilityHint("Signs out and returns to the login screen")
                }
            }
            .formStyle(.grouped)
            .scrollIndicators(.hidden)
        }
    }

    private func toggleLaunchAtLogin(_ enabled: Bool) {
        launchAtLoginError = nil
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            launchAtLoginError = "Failed to update: \(error.localizedDescription)"
            // Revert the setting on failure
            appState.settings.launchAtLogin = !enabled
        }
    }

    private func updateDockVisibility(_ showInDock: Bool) {
        if showInDock {
            NSApp.setActivationPolicy(.regular)
        } else {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}
