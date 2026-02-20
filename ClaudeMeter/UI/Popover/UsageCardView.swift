//
//  UsageCardView.swift
//  ClaudeMeter
//
//  Copyright (c) 2026 ClaudeMeter. All rights reserved.
//  Licensed under the MIT License. See LICENSE file.
//

import SwiftUI

struct UsageCardView: View {
    let title: String
    let usage: Double // Percentage 0-100
    let resetsAt: Date?

    private var progressColor: Color {
        ColorTheme.colorForUsage(usage)
    }

    private var usageLevel: String {
        switch usage {
        case 0..<50: return "low"
        case 50..<75: return "moderate"
        case 75..<90: return "high"
        default: return "critical"
        }
    }

    private var accessibilityDescription: String {
        var description = "\(title): \(Int(usage)) percent, \(usageLevel) usage"
        if let date = resetsAt {
            description += ". Resets in \(date.timeRemainingFormatted(style: .accessibilityFriendly))"
        }
        return description
    }

    var body: some View {
        VStack(spacing: 8) {
            // Header
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                AnimatedPercentage(value: usage)
            }

            // Progress bar
            ProgressBarView(
                progress: usage / 100.0,
                showPercentage: false,
                height: 4
            )
            .frame(maxWidth: .infinity)

            // Reset countdown
            if let date = resetsAt {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption2)
                    Text(date.timeRemainingFormatted())
                        .font(.caption2)
                }
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityValue("\(Int(usage)) percent")
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        UsageCardView(
            title: "5-Hour Limit",
            usage: 45,
            resetsAt: Date().addingTimeInterval(3600)
        )
        Divider().opacity(0.15)
        UsageCardView(
            title: "7-Day Limit",
            usage: 78,
            resetsAt: Date().addingTimeInterval(86400 * 3)
        )
        Divider().opacity(0.15)
        UsageCardView(
            title: "Opus Limit",
            usage: 95,
            resetsAt: Date().addingTimeInterval(86400 * 5)
        )
    }
    .padding()
    .frame(width: 340)
}
