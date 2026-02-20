//
//  PopoverView.swift
//  ClaudeMeter
//
//  Copyright (c) 2026 ClaudeMeter. All rights reserved.
//  Licensed under the MIT License. See LICENSE file.
//

import SwiftUI

struct PopoverView: View {
    @ObservedObject var appState: AppState
    @State private var showingSettings = false

    // Size constants
    private let popoverWidth: CGFloat = 360
    private let popoverHeight: CGFloat = 420
    private let contentPadding: CGFloat = 20

    var body: some View {
        ZStack {
            // Main content
            VStack(spacing: 0) {
                headerView
                    .padding(.horizontal, contentPadding)
                    .padding(.top, 16)
                    .padding(.bottom, 12)

                // Content
                contentView

                footerView
                    .padding(.horizontal, contentPadding)
                    .padding(.vertical, 10)
            }
            .opacity(showingSettings ? 0 : 1)

            // Settings - full page (not overlay)
            if showingSettings {
                SettingsView(appState: appState, onDismiss: {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        showingSettings = false
                    }
                })
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .frame(width: popoverWidth, height: popoverHeight)
        .preferredColorScheme(appState.settings.colorScheme.colorScheme)
        .animation(.easeInOut(duration: 0.25), value: showingSettings)
    }

    // MARK: - Content

    @ViewBuilder
    private var contentView: some View {
        if let data = appState.usageData {
            usageContentView(data: data)
        } else if let error = appState.error {
            errorView(error: error)
        } else {
            emptyStateView
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: 12) {
            Text("Usage")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
                .accessibilityAddTraits(.isHeader)

            Spacer()

            ProgressView()
                .controlSize(.small)
                .opacity(appState.isLoading ? 1 : 0)
                .accessibilityLabel("Loading usage data")

            // Glass pill buttons
            GlassEffectContainer {
                HStack(spacing: 2) {
                    Button(action: {
                        Task { await appState.refresh() }
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12, weight: .medium))
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: .circle)
                    .help("Refresh")
                    .accessibilityLabel("Refresh")

                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showingSettings = true
                        }
                    }) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 12, weight: .medium))
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: .circle)
                    .help("Settings")
                    .accessibilityLabel("Settings")

                    Button(action: {
                        NSApplication.shared.terminate(nil)
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .semibold))
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: .circle)
                    .help("Quit")
                    .accessibilityLabel("Quit")
                }
            }
        }
    }

    // MARK: - Usage Content

    private func usageContentView(data: UsageData) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                // Build list of visible cards with dividers between them
                let cards = visibleCards(data: data)
                ForEach(Array(cards.enumerated()), id: \.offset) { index, card in
                    card
                    if index < cards.count - 1 {
                        Divider()
                            .opacity(0.15)
                            .padding(.vertical, 6)
                    }
                }
            }
            .padding(.horizontal, contentPadding)
            .padding(.vertical, 8)
        }
    }

    // Helper to collect visible card views
    private func visibleCards(data: UsageData) -> [AnyView] {
        var cards: [AnyView] = []

        if let fiveHour = data.fiveHour {
            cards.append(AnyView(UsageCardView(
                title: "5-Hour Limit",
                usage: fiveHour.utilization,
                resetsAt: fiveHour.resetsAt
            )))
        }

        if let sevenDay = data.sevenDay {
            cards.append(AnyView(UsageCardView(
                title: "7-Day Limit",
                usage: sevenDay.utilization,
                resetsAt: sevenDay.resetsAt
            )))
        }

        if appState.settings.showSonnetLimit, let sonnet = data.sevenDaySonnet {
            cards.append(AnyView(UsageCardView(
                title: "Sonnet Limit",
                usage: sonnet.utilization,
                resetsAt: sonnet.resetsAt
            )))
        }

        if appState.settings.showOpusLimit, let opus = data.sevenDayOpus {
            cards.append(AnyView(UsageCardView(
                title: "Opus Limit",
                usage: opus.utilization,
                resetsAt: opus.resetsAt
            )))
        }

        if appState.settings.showExtraUsage,
           let extra = data.extraUsage,
           extra.isEnabled {
            cards.append(AnyView(ExtraUsageCardView(extraUsage: extra)))
        }

        return cards
    }

    // MARK: - Error View

    private func errorView(error: Error) -> some View {
        VStack(spacing: 12) {
            Spacer()

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 32))
                .foregroundStyle(ColorTheme.orange)

            Text("Error loading data")
                .font(.headline)

            Text(error.localizedDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            if let appError = error as? AppError,
               let suggestion = appError.recoverySuggestion {
                Text(suggestion)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Button("Retry") {
                Task { await appState.refresh() }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Spacer()
        }
        .padding()
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Spacer()

            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)

            Text("No Usage Data")
                .font(.headline)

            Text("Click refresh to load your Claude Code usage.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Refresh") {
                Task { await appState.refresh() }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Spacer()
        }
        .padding()
    }

    // MARK: - Footer

    private var footerView: some View {
        HStack {
            if let lastUpdate = appState.lastUpdateTime {
                Text("Updated \(lastUpdate.relativeDescription)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
    }
}

// MARK: - Preview

#Preview {
    PopoverView(appState: AppState())
}
