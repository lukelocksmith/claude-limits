//
//  ExtraUsageCardView.swift
//  ClaudeMeter
//
//  Copyright (c) 2026 ClaudeMeter. All rights reserved.
//  Licensed under the MIT License. See LICENSE file.
//

import SwiftUI

struct ExtraUsageCardView: View {
    let extraUsage: ExtraUsageData

    private var progressColor: Color {
        ColorTheme.colorForUsage(extraUsage.utilization)
    }

    private var accessibilityDescription: String {
        "Extra Usage: \(extraUsage.spentFormatted) of \(extraUsage.limitFormatted) used, \(Int(extraUsage.utilization)) percent"
    }

    var body: some View {
        VStack(spacing: 8) {
            // Header
            HStack(alignment: .firstTextBaseline) {
                Text("Extra Usage")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                AnimatedPercentage(value: extraUsage.utilization)
            }

            // Progress bar
            ProgressBarView(
                progress: extraUsage.utilization / 100.0,
                showPercentage: false,
                height: 4
            )
            .frame(maxWidth: .infinity)

            // Spent / Limit
            HStack(spacing: 4) {
                Image(systemName: "creditcard")
                    .font(.caption2)
                Text("\(extraUsage.spentFormatted) / \(extraUsage.limitFormatted)")
                    .font(.caption2)
            }
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityValue("\(Int(extraUsage.utilization)) percent")
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        ExtraUsageCardView(
            extraUsage: ExtraUsageData(
                isEnabled: true,
                monthlyLimit: 6000,
                usedCredits: 1091,
                utilization: 18.18
            )
        )
    }
    .padding()
    .frame(width: 340)
}
