//
//  UsageData.swift
//  ClaudeMeter
//
//  Copyright (c) 2026 puq.ai. All rights reserved.
//  Licensed under the MIT License. See LICENSE file.
//

import Foundation

struct UsageData: Codable, Equatable {
    let fiveHour: UsageWindow?
    let sevenDay: UsageWindow?
    let sevenDayOpus: UsageWindow?
    let sevenDaySonnet: UsageWindow?
    let sevenDayOauthApps: UsageWindow?
    let sevenDayCowork: UsageWindow?
    let extraUsage: ExtraUsageData?
    let fetchedAt: Date

    // CodingKeys for snake_case API response mapping
    enum CodingKeys: String, CodingKey {
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
        case sevenDayOpus = "seven_day_opus"
        case sevenDaySonnet = "seven_day_sonnet"
        case sevenDayOauthApps = "seven_day_oauth_apps"
        case sevenDayCowork = "seven_day_cowork"
        case extraUsage = "extra_usage"
        case fetchedAt = "fetched_at"
    }

    // Custom initializer for creating instances programmatically
    init(
        fiveHour: UsageWindow?,
        sevenDay: UsageWindow?,
        sevenDayOpus: UsageWindow?,
        sevenDaySonnet: UsageWindow? = nil,
        sevenDayOauthApps: UsageWindow? = nil,
        sevenDayCowork: UsageWindow? = nil,
        extraUsage: ExtraUsageData? = nil,
        fetchedAt: Date = Date()
    ) {
        self.fiveHour = fiveHour
        self.sevenDay = sevenDay
        self.sevenDayOpus = sevenDayOpus
        self.sevenDaySonnet = sevenDaySonnet
        self.sevenDayOauthApps = sevenDayOauthApps
        self.sevenDayCowork = sevenDayCowork
        self.extraUsage = extraUsage
        self.fetchedAt = fetchedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        fiveHour = try container.decodeIfPresent(UsageWindow.self, forKey: .fiveHour)
        sevenDay = try container.decodeIfPresent(UsageWindow.self, forKey: .sevenDay)
        sevenDayOpus = try container.decodeIfPresent(UsageWindow.self, forKey: .sevenDayOpus)
        sevenDaySonnet = try container.decodeIfPresent(UsageWindow.self, forKey: .sevenDaySonnet)
        sevenDayOauthApps = try container.decodeIfPresent(UsageWindow.self, forKey: .sevenDayOauthApps)
        sevenDayCowork = try container.decodeIfPresent(UsageWindow.self, forKey: .sevenDayCowork)
        extraUsage = try container.decodeIfPresent(ExtraUsageData.self, forKey: .extraUsage)
        // fetchedAt may not come from API, default to now
        fetchedAt = try container.decodeIfPresent(Date.self, forKey: .fetchedAt) ?? Date()
    }
}

struct ExtraUsageData: Codable, Equatable {
    let isEnabled: Bool
    let monthlyLimit: Double   // in cents
    let usedCredits: Double    // in cents
    let utilization: Double    // 0-100

    enum CodingKeys: String, CodingKey {
        case isEnabled = "is_enabled"
        case monthlyLimit = "monthly_limit"
        case usedCredits = "used_credits"
        case utilization
    }

    /// Spent amount formatted as currency (cents → euros)
    var spentFormatted: String {
        let euros = usedCredits / 100.0
        return String(format: "€%.2f", euros)
    }

    /// Monthly limit formatted as currency (cents → euros)
    var limitFormatted: String {
        let euros = monthlyLimit / 100.0
        // Show without decimals if it's a round number
        if euros.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "€%.0f", euros)
        }
        return String(format: "€%.2f", euros)
    }
}

struct UsageWindow: Codable, Equatable {
    let utilization: Double      // 0-100 percentage
    let resetsAt: Date?          // ISO 8601

    enum CodingKeys: String, CodingKey {
        case utilization
        case resetsAt = "resets_at"
    }
}
